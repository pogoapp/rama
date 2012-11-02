net       = require 'net'
fs        = require 'fs'
pty       = require 'pty.js'

anyone_connected   = false
last_term_data     = null
last_socket_data   = null
term_cmd           = process.env.POGO_CMD || "bash"
open_timeout_limit = 20000
read_timeout_limit = 60000

server = net.createServer (socket) ->
  anyone_connected = true
  last_term_data   = new Date
  
  term = pty.fork 'bash', ['-l', '-c', term_cmd], {
    cols: parseInt(process.env.TERM_COLS || 80),
    rows: parseInt(process.env.TERM_ROWS || 30),
    cwd: '/app', 
  }
  
  socket.on 'data', (data) ->
    last_socket_data = new Date
    term.write(data)
  
  term.on 'data', (data) ->
    last_term_data = new Date
    socket.write(data)
    
  term.on 'close', ->
    console.log('terminal closed, exiting process')
    process.exit()

server.listen (process.env.PORT || 8000), ->
  console.log('server bound to :' + (process.env.PORT || 8000))

# initial connection timeout
stop_unless_connected = ->
  unless anyone_connected
    console.log("no one connected: exiting")
    process.exit()

# idle connection timeout
exit_if_idle = ->
  now = new Date
  last_term_ago   = now - last_term_data
  last_socket_ago = now - last_socket_data
  
  if anyone_connected && last_term_ago > read_timeout_limit && last_socket_ago > read_timeout_limit
    console.log("timeout in #{read_timeout_limit} ms (term: #{last_term_ago} | socket: #{last_socket_ago}), exiting process")
    process.exit()
  else
    setTimeout exit_if_idle, (read_timeout_limit / 6)

setTimeout stop_unless_connected, open_timeout_limit
exit_if_idle()