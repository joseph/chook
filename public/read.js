var $ = function (id) { return document.getElementById(id) };
var ochook = {};


function setup(part) {
  ochook.inited = (ochook.inited || '') + part;
  if (ochook.inited == 'a' || ochook.inited == 'b') {
    return;
  }
  var frame = $('reader');
  frame.contentDocument.documentElement.setAttribute(
    'id',
    'RS:org.ochook.reader'
  );
  var bdy = frame.contentDocument.body;
  bdy.style.wordWrap = "break-word";
  bdy.style.padding = "0 2em";
  var cover = $('cover');
  var nav = $('nav');
  var frame = $('reader');
  nav.style.width = cover.offsetWidth+"px";
  frame.style.width = cover.offsetWidth+"px";
}


function read() {
  var cover = $('cover');
  var nav = $('nav');
  var frame = $('reader');
  frame.style.visibility = "visible";
  nav.style.display = "block";
  cover.style.display = "none";
  applyTOC(frame);
}


function applyTOC(frame) {
  var doc = frame.contentDocument;
  $('tocArrLeft').onclick = function () {
    if (!ochook.prevChapter) { return; }
    ochook.prevChapter.anchor.scrollIntoView();
  }
  $('tocArrRight').onclick = function () {
    if (!ochook.nextChapter) { return; }
    ochook.nextChapter.anchor.scrollIntoView();
  }

  ochook.tocCntr = $('tocCntr');
  ochook.tocTab = $('tocTab');
  ochook.tocTab.onclick = toggleTOC;

  lineariseTOC(frame);
  updateTOCTab(frame);
  frame.contentWindow.addEventListener(
    "scroll",
    function () { updateTOCTab(frame); },
    true
  );
}


function toggleTOC() {
  ochook.tocCntr.style.display =
    (ochook.tocCntr.style.display == "block") ?  "none" : "block";
}


function lineariseTOC(frame) {
  ochook.linearTOC = [];
  var curse = function (list) {
    for (var i = 0; i < list.childNodes.length; ++i) {
      var ch = list.childNodes[i];
      if (ch.tagName.toLowerCase() == "li") {
        for (var j = 0; j < ch.childNodes.length; ++j) {
          var lich = ch.childNodes[j];
          if (!lich.tagName) {
          } else if (lich.tagName.toLowerCase() == "ol") {
            curse(lich);
          } else if (lich.tagName.toLowerCase() == "a") {
            prepTocItem(lich, frame);
          }
        }
      }
    }
  }
  curse($('tocCntr').getElementsByTagName('ol')[0]);
}


function prepTocItem(lich, frame) {
  var id = lich.getAttribute("href");
  id = id.replace(/^#/, '');
  var anchor = frame.contentDocument.getElementById(id);
  if (anchor) {
    ochook.linearTOC.push({
      id: id,
      anchor: anchor,
      offset: anchor.offsetTop
    });
    lich.onclick = function (l) {
      anchor.scrollIntoView();
      toggleTOC();
      return false;
    }
  } else {
    console.log("ID not found: "+id);
  }
}


function updateTOCTab(frame) {
  var sY = frame.contentWindow.scrollY;
  var setTabText = function (tocItem) {
    ochook.tocTab.innerHTML = tocItem.anchor.innerHTML;
  }
  for (var i = 0; i < ochook.linearTOC.length; ++i) {
    var n0 = ochook.linearTOC[i], n1 = ochook.linearTOC[i+1];
    if (n0 && n1) {
      if (
        (n0.offset <= sY && n1.offset > sY) ||
        (n0.offset > sY)
      ){
        setTabText(n0);
        ochook.nextChapter = n1;
        ochook.prevChapter = ochook.linearTOC[i-1] || n0;
        break;
      }
    } else if (n0) {
      setTabText(n0);
      ochook.nextChapter = null;
      ochook.prevChapter = ochook.linearTOC[i-1] || n0;
      break;
    }
  }
}
