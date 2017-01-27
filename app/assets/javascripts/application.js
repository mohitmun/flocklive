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
      reaction_type = $(this).find(".react").data("type");
       $.ajax({
        url: "/save_reaction",
        type: 'POST',
        data: {"type" : type, "id" : id, "reaction_type": reaction_type},
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
