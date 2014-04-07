WebSocket = require('websocket').client
uuid = require 'node-uuid'
crypto = require 'crypto'
{EventEmitter} = require "events"

class PusherChannel extends EventEmitter
  
  constructor: (@channel_name, @channel_data) ->


class PusherClient extends EventEmitter

  @debug = false
  
  state: 
    name: "disconnected"
    socket_id: null

  constructor: (@credentials) ->

  subscribe: (channel_name, channel_data = {}) =>
    stringToSign = "#{@state.socket_id}:#{channel_name}:#{JSON.stringify(channel_data)}"
    auth = @credentials.key + ':' + crypto.createHmac('sha256', @credentials.secret).update(stringToSign).digest 'hex'
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
    if PusherClient.debug then console.log "unsubscribing from #{channel_name}"
    stringToSign = "#{@state.socket_id}:#{channel_name}:#{JSON.stringify(channel_data)}"
    auth = @credentials.key + ':' + crypto.createHmac('sha256', @credentials.secret).update(stringToSign).digest 'hex'
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

  # name this function better
  resetActivityCheck: =>
    if @activityTimeout then clearTimeout @activityTimeout
    if @waitingTimeout then clearTimeout @waitingTimeout
    @activityTimeout = setTimeout(
       =>
        if PusherClient.debug then console.log "pinging pusher to see if active at #{(new Date).toLocaleTimeString()}"
        @connection.sendUTF JSON.stringify event: "pusher:ping", id: uuid.v1(), data: {} 
        @waitingTimeout = setTimeout(
          =>
            if PusherClient.debug then console.log "disconnecting because of inactivity at #{(new Date).toLocaleTimeString()}"
            @unsubscribe c.channel_name, c.channel_data for c of @channels
            if PusherClient.debug then console.log "connetcing again at #{(new Date).toLocaleTimeString()}"
            if @connection.state isnt "open"
              @connect()
          30000
        )
      120000
    )

  connect: =>
    @client =  new WebSocket()  
    @channels = {}
    @client.on 'connect', (@connection) =>
      if PusherClient.debug
        console.log 'connected to pusher '
        console.log @connection.state
      @connection.on 'message', (msg) =>
        @resetActivityCheck()
        @recieveMessage msg
      @connection.on 'close', =>
        @connect()
    if PusherClient.debug
      console.log "trying connecting to pusher on - wss://ws.pusherapp.com:443/app/#{@credentials.key}?client=node-pusher-server&version=0.0.1&protocol=5&flash=false"
    @client.connect "wss://ws.pusherapp.com:443/app/#{@credentials.key}?client=node-pusher-server&version=0.0.1&protocol=5&flash=false"

  recieveMessage: (msg) =>
    if msg.type is 'utf8' 
      payload = JSON.parse msg.utf8Data
      if payload.event is "pusher:connection_established"
        data = JSON.parse payload.data
        @state = name: "connected", socket_id: data.socket_id
        if PusherClient.debug then console.log @state
        @emit 'connect'
      if payload.event is "pusher_internal:subscription_succeeded"
        channel = @channels[payload.channel]
        if channel then channel.emit 'success'
      channel = @channels[payload.channel]
      if PusherClient.debug
        console.log "got event #{payload.event} on #{(new Date).toLocaleTimeString()}"
      if payload.event is "pusher:error" and PusherClient.debug 
        console.log payload
      if channel 
        channel.emit payload.event, JSON.parse payload.data

module.exports.PusherClient = PusherClient