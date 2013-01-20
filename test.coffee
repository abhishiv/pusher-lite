PusherClient = require('./lib/pusher-node-client').PusherClient

pusher_client = new PusherClient
  appId: (process.env.PUSHER_APP_ID or app_id)
  key: (process.env.PUSHER_KEY or pusher_key)
  secret: (process.env.PUSHER_SECRET or pusher_secret)

pres = null
pusher_client.on 'connect', () ->
  pres = pusher_client.subscribe("presence-users", {user_id: "system"})

  pres.on 'success', () ->

    pres.on 'pusher_internal:member_removed', (data) ->
      console.log "member_removed"


    pres.on 'pusher_internal:member_added', (data) ->
      console.log "member_added"

pusher_client.connect()


