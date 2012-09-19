# A pusher client for the server

## How to use

```javascript

PusherServer = require('pusher-server').PusherServer

pusher_server = new PusherServer
  appId: (process.env.PUSHER_APP_ID or app_id)
  key: (process.env.PUSHER_KEY or pusher_key)
  secret: (process.env.PUSHER_SECRET or pusher_secret)

pusher_server.on 'connect', () ->
  pres = pusher_server.subscribe("presence-users", {user_id: "system"})

  pres.on 'success', () ->

    pres.on 'pusher_internal:member_removed', (data) ->
      console.log "member_removed"


    pres.on 'pusher_internal:member_added', (data) ->
      console.log "member_added"

pusher_server.connect()

```

```javascript

PUSHER_APP_ID=xx PUSHER_KEY=xxx PUSHER_SECRET=xxx  node test.js

```

## License

This code is free to use under the terms of the MIT license.
