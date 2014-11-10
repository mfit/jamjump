var net = require('http');


var server = net.createServer(handler);
server.listen(1337, '127.0.0.1');

var io = require('socket.io')(server);
var fs = require('fs');
console.log("Server started ...");

function handler (req, res) {
  fs.readFile(__dirname + '/index.html',
  function (err, data) {
    if (err) {
      res.writeHead(500);
      return res.end('Error loading index.html');
    }
    res.writeHead(200);
    res.end(data);
  });
}

io.on('connection', function(socket){
  console.log('a user connected');
  socket.on('gup', function (data) {
    console.log(data);
    io.emit('gup', data);
  });
  socket.on('disconnect', function(){
    console.log('user disconnected');
  });

});
