// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .

    function god_function(bc, create_bc) {
      // body...
            // recording is disabled because it is resulting for browser-crash
            // if you enable below line, please also uncomment above "RecordRTC.js"
            var enableRecordings = false;

            var connection = new RTCMultiConnection(null, {
                useDefaultDevices: true // if we don't need to force selection of specific devices
            });

            // its mandatory in v3
            connection.enableScalableBroadcast = true;

            // each relaying-user should serve only 1 users
            connection.maxRelayLimitPerUser = 1;

            // we don't need to keep room-opened
            // scalable-broadcast.js will handle stuff itself.
            connection.autoCloseEntireSession = true;

            // by default, socket.io server is assumed to be deployed on your own URL
            connection.socketURL = 'https://806ff849.ngrok.io/';

            // comment-out below line if you do not have your own socket.io server
            // connection.socketURL = 'https://rtcmulticonnection.herokuapp.com:443/';

            connection.socketMessageEvent = 'scalable-media-broadcast-demo';

            // document.getElementById('broadcast-id').value = connection.userid;

            // user need to connect server, so that others can reach him.
            connection.connectSocket(function(socket) {
                socket.on('logs', function(log) {
                    // document.querySelector('h1').innerHTML = log.replace(/</g, '----').replace(/>/g, '___').replace(/----/g, '(<span style="color:red;">').replace(/___/g, '</span>)');
                });

                // this event is emitted when a broadcast is already created.
                socket.on('join-broadcaster', function(hintsToJoinBroadcast) {
                    console.log('join-broadcaster', hintsToJoinBroadcast);

                    connection.session = hintsToJoinBroadcast.typeOfStreams;
                    connection.sdpConstraints.mandatory = {
                        OfferToReceiveVideo: !!connection.session.video,
                        OfferToReceiveAudio: !!connection.session.audio
                    };
                    connection.broadcastId = hintsToJoinBroadcast.broadcastId;
                    connection.join(hintsToJoinBroadcast.userid);
                });

                socket.on('rejoin-broadcast', function(broadcastId) {
                    console.log('rejoin-broadcast', broadcastId);

                    connection.attachStreams = [];
                    socket.emit('check-broadcast-presence', broadcastId, function(isBroadcastExists) {
                        if(!isBroadcastExists) {
                            // the first person (i.e. real-broadcaster) MUST set his user-id
                            connection.userid = broadcastId;
                        }

                        socket.emit('join-broadcast', {
                            broadcastId: broadcastId,
                            userid: connection.userid,
                            typeOfStreams: connection.session
                        });
                    });
                });

                socket.on('broadcast-stopped', function(broadcastId) {
                    // alert('Broadcast has been stopped.');
                    // location.reload();
                    console.error('broadcast-stopped', broadcastId);
                    // alert('This broadcast has been stopped.');
                    location.reload()
                });

                // this event is emitted when a broadcast is absent.
                socket.on('start-broadcasting', function(typeOfStreams) {
                    console.log('start-broadcasting', typeOfStreams);

                    // host i.e. sender should always use this!
                    connection.sdpConstraints.mandatory = {
                        OfferToReceiveVideo: false,
                        OfferToReceiveAudio: false
                    };
                    connection.session = typeOfStreams;

                    // "open" method here will capture media-stream
                    // we can skip this function always; it is totally optional here.
                    // we can use "connection.getUserMediaHandler" instead
                    connection.open(connection.userid, function() {
                        showRoomURL(connection.sessionid);
                    });
                });
            });

            window.onbeforeunload = function() {
                // Firefox is ugly.
                document.getElementById('open-or-join-'+ bc).disabled = false;
            };

            var videoPreview = document.getElementById('video-preview-'+bc);

            connection.onstream = function(event) {
                if(connection.isInitiator && event.type !== 'local') {
                    return;
                }

                if(event.mediaElement) {
                    event.mediaElement.pause();
                    delete event.mediaElement;
                }

                connection.isUpperUserLeft = false;
                videoPreview.src = URL.createObjectURL(event.stream);
                videoPreview.play();

                videoPreview.userid = event.userid;

                if(event.type === 'local') {
                    videoPreview.muted = true;
                }

                if (connection.isInitiator == false && event.type === 'remote') {
                    // he is merely relaying the media
                    connection.dontCaptureUserMedia = true;
                    connection.attachStreams = [event.stream];
                    connection.sdpConstraints.mandatory = {
                        OfferToReceiveAudio: false,
                        OfferToReceiveVideo: false
                    };

                    var socket = connection.getSocket();
                    socket.emit('can-relay-broadcast');

                    if(connection.DetectRTC.browser.name === 'Chrome') {
                        connection.getAllParticipants().forEach(function(p) {
                            if(p + '' != event.userid + '') {
                                var peer = connection.peers[p].peer;
                                peer.getLocalStreams().forEach(function(localStream) {
                                    peer.removeStream(localStream);
                                });
                                peer.addStream(event.stream);
                                connection.dontAttachStream = true;
                                connection.renegotiate(p);
                                connection.dontAttachStream = false;
                            }
                        });
                    }

                    if(connection.DetectRTC.browser.name === 'Firefox') {
                        // Firefox is NOT supporting removeStream method
                        // that's why using alternative hack.
                        // NOTE: Firefox seems unable to replace-tracks of the remote-media-stream
                        // need to ask all deeper nodes to rejoin
                        connection.getAllParticipants().forEach(function(p) {
                            if(p + '' != event.userid + '') {
                                connection.replaceTrack(event.stream, p);
                            }
                        });
                    }

                    // Firefox seems UN_ABLE to record remote MediaStream
                    // WebAudio solution merely records audio
                    // so recording is skipped for Firefox.
                    if(connection.DetectRTC.browser.name === 'Chrome') {
                        repeatedlyRecordStream(event.stream);
                    }
                }
            };

            // ask node.js server to look for a broadcast
            // if broadcast is available, simply join it. i.e. "join-broadcaster" event should be emitted.
            // if broadcast is absent, simply create it. i.e. "start-broadcasting" event should be fired.
            document.getElementById('open-or-join-'+ bc).onclick = function() {
                // var broadcastId = document.getElementById('broadcast-id').value;
                var broadcastId = bc;

                if (broadcastId.replace(/^\s+|\s+$/g, '').length <= 0) {
                    // alert('Please enter broadcast-id');
                    //document.getElementById('broadcast-id').focus();
                    return;
                }

                document.getElementById('open-or-join-'+ bc).disabled = true;

                connection.session = {
                    audio: true,
                    video: true,
                    oneway: true
                };
                window.conn = connection;
                var socket = connection.getSocket();

                socket.emit('check-broadcast-presence', broadcastId, function(isBroadcastExists) {
                    if(!isBroadcastExists) {
                        // the first person (i.e. real-broadcaster) MUST set his user-id
                        connection.userid = broadcastId;
                    }

                    console.log('check-broadcast-presence', broadcastId, isBroadcastExists);

                    socket.emit('join-broadcast', {
                        broadcastId: broadcastId,
                        userid: connection.userid,
                        typeOfStreams: connection.session
                    });
                });
            };

            connection.onstreamended = function() {};

            connection.onleave = function(event) {
                if(event.userid !== videoPreview.userid) return;

                var socket = connection.getSocket();
                socket.emit('can-not-relay-broadcast');

                connection.isUpperUserLeft = true;

                if(allRecordedBlobs.length) {
                    // playing lats recorded blob
                    var lastBlob = allRecordedBlobs[allRecordedBlobs.length - 1];
                    videoPreview.src = URL.createObjectURL(lastBlob);
                    videoPreview.play();
                    allRecordedBlobs = [];
                }
                else if(connection.currentRecorder) {
                    var recorder = connection.currentRecorder;
                    connection.currentRecorder = null;
                    recorder.stopRecording(function() {
                        if(!connection.isUpperUserLeft) return;

                        videoPreview.src = URL.createObjectURL(recorder.blob);
                        videoPreview.play();
                    });
                }

                if(connection.currentRecorder) {
                    connection.currentRecorder.stopRecording();
                    connection.currentRecorder = null;
                }
            };

            var allRecordedBlobs = [];

            function repeatedlyRecordStream(stream) {
                if(!enableRecordings) {
                    return;
                }

                connection.currentRecorder = RecordRTC(stream, {
                    type: 'video'
                });

                connection.currentRecorder.startRecording();

                setTimeout(function() {
                    if(connection.isUpperUserLeft || !connection.currentRecorder) {
                        return;
                    }

                    connection.currentRecorder.stopRecording(function() {
                        allRecordedBlobs.push(connection.currentRecorder.blob);

                        if(connection.isUpperUserLeft) {
                            return;
                        }

                        connection.currentRecorder = null;
                        repeatedlyRecordStream(stream);
                    });
                }, 30 * 1000); // 30-seconds
            };

            function disableInputButtons() {
                document.getElementById('open-or-join-'+ bc).disabled = true;
                //document.getElementById('broadcast-id').disabled = true;
            }

            // ......................................................
            // ......................Handling broadcast-id................
            // ......................................................

            function showRoomURL(broadcastId) {
                var roomHashURL = '#' + broadcastId;
                var roomQueryStringURL = '?simple=true&broadcastId=' + broadcastId;

                var html = '<h2>Unique URL for your room:</h2><br>';

                html += 'Hash URL: <a href="' + roomHashURL + '" target="_blank">' + roomHashURL + '</a>';
                html += '<br>';
                html += 'QueryString URL: <a href="' + roomQueryStringURL + '" target="_blank">' + roomQueryStringURL + '</a>';

                var roomURLsDiv = document.getElementById('room-urls');
                // roomURLsDiv.innerHTML = html;

                // roomURLsDiv.style.display = 'block';
            }
            (function() {
                var params = {},
                    r = /([^&=]+)=?([^&]*)/g;

                function d(s) {
                    return decodeURIComponent(s.replace(/\+/g, ' '));
                }
                var match, search = window.location.search;
                while (match = r.exec(search.substring(1)))
                    params[d(match[1])] = d(match[2]);
                window.params = params;
            })();

            var broadcastId = bc;
            if (localStorage.getItem(connection.socketMessageEvent)) {
                broadcastId = localStorage.getItem(connection.socketMessageEvent);
            } else {
                broadcastId = connection.token();
            }

            var hashString = location.hash.replace('#', '');
            if(hashString.length && hashString.indexOf('comment-') == 0) {
              hashString = '';
            }
            console.log("dude dude");
            // var broadcastId = params.broadcastId;
            if(!broadcastId && hashString.length) {
                broadcastId = hashString;
            }
            var broadcastId = bc;
            console.log("===" + broadcastId);
            // if(broadcastId && broadcastId.length) {
            //     //document.getElementById('broadcast-id').value = broadcastId;
            //     localStorage.setItem(connection.socketMessageEvent, broadcastId);

            //     // auto-join-room
            //     (function reCheckRoomPresence() {
            //         connection.checkPresence(broadcastId, function(isRoomExists) {
            //             if(isRoomExists) {
            //                 document.getElementById('open-or-join-'+ bc).onclick();
            //                 return;
            //             }

            //             setTimeout(reCheckRoomPresence, 5000);
            //         });
            //     })();

            //     disableInputButtons();
            // }

            // below section detects how many users are viewing your broadcast

            // connection.onNumberOfBroadcastViewersUpdated = function(event) {
            //     if (!connection.isInitiator) return;

            //     document.getElementById('broadcast-viewers-counter').innerHTML = 'Number of broadcast viewers: <b>' + event.numberOfBroadcastViewers + '</b>';
            // };
    }

     function start_react(){  var isAnimationEnable = 0;
            var interVal;
      
            $(document).ready(function() {
          $(".showEmotions").unbind();
              $(".showEmotions").hover(function() {
      
                if (isAnimationEnable == 0) {
                  $(this).find(".emoji-reactions").show().css('opacity', '1');
                  $(this).find(".emoji-reactions span").velocity("transition.bounceUpIn", {
                    stagger: 80
                  });
                  current_div = this
                  isAnimationEnable = 1;
                  interVal = setInterval(function() {
                    if (isAnimationEnable == 1) {
                      cursorListener($(current_div));
                    }
                  }, 1000);
                }
      
              }, function() {
      
              });
      
              function cursorListener(a) {
                var isHovered = !!a.find('.emoji-reactions , .actionBox').
                filter(function() {
                  return $(this).is(":hover");
                }).length;
                // console.log(isHovered);
                if (!isHovered) {
                  a.find(".emoji-reactions").velocity("transition.fadeOut", {
                    delay: 500
                  });
                  clearInterval(interVal);
                  isAnimationEnable = 0;
      
                }
              }
      
            });}
            // start_react();
function ajax_init() {
  // body...
  function temp() {
      // body...
      type = $(this).parents(".actionBox").data("type");
      id = $(this).parents(".actionBox").data("id");
      my_tweets = $(this).parents(".actionBox").data("my-tweets");
      reaction_type = $(this).find(".react").data("type");
       $.ajax({
        url: "/save_reaction",
        type: 'POST',
        data: {"type" : type, "id" : id, "reaction_type": reaction_type, "my_tweets": my_tweets},
        success: function(data){
          console.log("wohhoo:" +data);
          $(".listitems").html(data);
          start_react();
          run_sort();
        },
        error: function(data){

        }
      });
      console.log("reaction clicked:" + $(this).find(".react").data("type"));
    }
  $(document).off("click", ".reaction").on("click", ".reaction", temp);
}

           function run_sort(){$(".listitems .hashtag").sort(sort_li).appendTo('.listitems');
        function sort_li(a, b){
            return ($(b).data('position')) > ($(a).data('position')) ? 1 : -1;    
        }}
