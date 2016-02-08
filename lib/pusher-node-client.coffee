WebSocket = require('websocket').client
uuid = require('node-uuid')
crypto = require('crypto')
{EventEmitter} = require "events"
request = require 'request'
_ = require 'underscore'
packageInfo = require '../package.json'

class PusherChannel extends EventEmitter

  constructor: (channel_name, channel_data) ->
    @channel_name = channel_name
    @channel_data = channel_data

class PusherClient extends EventEmitter

  state:
    name: "disconnected"
    socket_id: null

  constructor: (credentials) ->
    @credentials = credentials

  subscribe: (channel_name, channel_data = {}) =>
    @getAuthtication channel_name, channel_data, (auth, channel_data) =>
      req =
        id: uuid.v1()
        event: "pusher:subscribe"
        data:
          channel: channel_name
          auth: auth
          channel_data: JSON.stringify channel_data
      @connection.sendUTF JSON.stringify req

    channel = @channels[channel_name]
    if channel
      new Error "Existing subscription to #{channel_name}"
      channel
    else
      channel = new PusherChannel channel_name, channel_data
      @channels[channel_name] = channel
      channel

  unsubscribe: (channel_name, channel_data = {}) =>
    console.log "unsubscribing from #{channel_name}"
    @getAuthtication channel_name, channel_data, (auth, channel_data) =>
      req =
        id: uuid.v1()
        event: "pusher:unsubscribe"
        data:
          channel: channel_name
          auth: auth
          channel_data: JSON.stringify channel_data
      @connection.sendUTF JSON.stringify req

    channel = @channels[channel_name]
    if channel
      delete @channels[channel_name]
      channel

    else
      new Error "No subscription to #{channel_name}"

  getAuthtication: (channel_name, channel_data, callback) =>
    if @credentials.authEndpoint || @credentials.auth
      {socket_id} = @state
      form = _.extend { channel_name, socket_id }, channel_data
      requestOpts = _.extend {
        method: 'POST'
        form: form
        url: @credentials.authEndpoint
      }, @credentials.auth || {}
      request requestOpts, (err, res, body) =>
        if res.statusCode is 200
          try
            data = JSON.parse body
            channel_data = try JSON.parse(data.channel_data) || channel_data
          catch e
            console.error e
            return
          callback data.auth, channel_data
        else
          console.error err || "Error #{res.statusCode} #{res.body}"
      return
    if @credentials.secret
      stringToSign = "#{@state.socket_id}:#{channel_name}:#{JSON.stringify(channel_data)}"
      callback @credentials.key + ':' + crypto.createHmac('sha256', @credentials.secret).update(stringToSign).digest('hex'), channel_data
      return
    throw new Error 'secret or authEndpoint is required to subscribe channel'

  # name this function better
  resetActivityCheck: () =>
    if @activityTimeout then clearTimeout @activityTimeout
    if @waitingTimeout then clearTimeout @waitingTimeout
    @activityTimeout = setTimeout(
      () =>
        console.log "pinging pusher to see if active at #{(new Date).toLocaleTimeString()}"
        @connection.sendUTF JSON.stringify({ event: "pusher:ping", id: uuid.v1(), data: {} })
        @waitingTimeout = setTimeout(
          () =>
            console.log "disconnecting because of inactivity at #{(new Date).toLocaleTimeString()}"
            _(@channels).each (channel) =>
                @unsubscribe channel.channel_name, channel.channel_data
            console.log "connetcing again at #{(new Date).toLocaleTimeString()}"
            if @connection.state isnt "open"
              @connect()
          30000
        )
      120000
    )

  connect: () =>
    @client =  new WebSocket()
    @channels = {}
    @client.on 'connect', (connection) =>
      console.log 'connected to pusher '
      @connection = connection
      console.log @connection.state
      @connection.on 'message', (msg) =>
        @resetActivityCheck()
        @recieveMessage msg
      @connection.on 'close', () =>
        @connect()
    wsURL = "wss://ws.pusherapp.com/app/#{@credentials.key}?client=#{packageInfo.name}&version=#{packageInfo.version}&protocol=7&flash=false"
    console.log "trying connecting to pusher on - #{wsURL}"
    @client.connect wsURL

  recieveMessage: (msg) =>
    if msg.type is 'utf8'
      payload = JSON.parse msg.utf8Data
      if payload.event is "pusher:connection_established"
        data = JSON.parse payload.data
        @state = { name: "connected", socket_id: data.socket_id }
        console.log @state
        @emit 'connect'
      if payload.event is "pusher_internal:subscription_succeeded"
        channel = @channels[payload.channel]
        if channel then channel.emit 'success'
      channel = @channels[payload.channel]
      console.log "got event #{payload.event} on #{(new Date).toLocaleTimeString()}"
      if payload.event is "pusher:error"
        console.log payload
      if channel
        channel.emit payload.event, JSON.parse payload.data

module.exports.PusherClient = PusherClient
