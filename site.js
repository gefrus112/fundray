/* Fundray site.js — progressive enhancement only.
   The site is fully usable without JavaScript; this file adds:
   1. Scroll-reveal animations (IntersectionObserver)
   2. The before/after compare slider drag logic
   3. Subtle header elevation on scroll
   v6: scroll progress bar, count-up stats, headline word rotator,
       terminal tab switcher, copy buttons, docs scrollspy + nav filter,
       bento card spotlight. All features degrade gracefully. */
(function () {
  "use strict";

  var reduced = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  document.documentElement.classList.add("js");

  /* 1 — scroll reveal */
  var revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && revealEls.length) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add("visible");
          io.unobserve(e.target);
        }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add("visible"); });
  }

  /* 2 — compare slider */
  document.querySelectorAll(".compare").forEach(function (cmp) {
    var range = cmp.querySelector(".cmp-range");
    if (!range) return;
    var apply = function () {
      cmp.style.setProperty("--pos", range.value + "%");
    };
    range.addEventListener("input", apply);
    range.addEventListener("change", apply);
    apply();
  });

  /* 3 — header elevation */
  var header = document.querySelector(".site-header");
  if (header) {
    var onScroll = function () {
      header.classList.toggle("scrolled", window.scrollY > 8);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
  }

  /* 4 — scroll progress bar (injected; all pages) */
  var progress = document.createElement("div");
  progress.className = "scroll-progress";
  progress.setAttribute("aria-hidden", "true");
  document.body.appendChild(progress);
  var setProgress = function () {
    var doc = document.documentElement;
    var max = doc.scrollHeight - doc.clientHeight;
    var y = window.scrollY || doc.scrollTop || 0;
    progress.style.width = max > 0 ? (y / max) * 100 + "%" : "0%";
  };
  window.addEventListener("scroll", setProgress, { passive: true });
  window.addEventListener("resize", setProgress);
  setProgress();

  /* 5 — count-up stats (elements carry data-count + optional data-suffix) */
  if ("IntersectionObserver" in window) {
    var counters = document.querySelectorAll("[data-count]");
    var cio = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        cio.unobserve(e.target);
        var el = e.target;
        var end = parseFloat(el.getAttribute("data-count"));
        var suffix = el.getAttribute("data-suffix") || "";
        if (reduced || isNaN(end)) {
          el.textContent = end + suffix;
          return;
        }
        var t0 = null;
        var dur = 1300;
        var tick = function (t) {
          if (t0 === null) t0 = t;
          var p = Math.min(1, (t - t0) / dur);
          p = 1 - Math.pow(1 - p, 3); /* ease-out cubic */
          el.textContent = Math.round(end * p) + suffix;
          if (p < 1) window.requestAnimationFrame(tick);
        };
        window.requestAnimationFrame(tick);
      });
    }, { threshold: 0.5 });
    counters.forEach(function (el) { cio.observe(el); });
  }

  /* 6 — headline word rotator (.rot carries data-words JSON) */
  document.querySelectorAll(".rot").forEach(function (el) {
    var words;
    try { words = JSON.parse(el.getAttribute("data-words")); }
    catch (err) { return; }
    if (!words || words.length < 2) return;
    if (reduced || !("IntersectionObserver" in window)) return;

    var idx = 0;
    var busy = false;
    var started = false;
    var swap = function () {
      if (busy) return;
      busy = true;
      el.classList.add("rot-out");
      window.setTimeout(function () {
        idx = (idx + 1) % words.length;
        el.textContent = words[idx];
        el.classList.remove("rot-out");
        el.classList.add("rot-in");
        window.setTimeout(function () {
          el.classList.remove("rot-in");
          busy = false;
        }, 320);
      }, 280);
    };
    var rio = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting || started) return;
        started = true;
        rio.unobserve(el);
        window.setInterval(swap, 2400);
      });
    }, { threshold: 0.4 });
    rio.observe(el);
  });

  /* 7 — terminal tab switcher (.js-tabs: .tab-btn + .tab-pane) */
  document.querySelectorAll(".js-tabs").forEach(function (wrap) {
    var btns = wrap.querySelectorAll(".tab-btn");
    var panes = wrap.querySelectorAll(".tab-pane");
    if (!btns.length || btns.length !== panes.length) return;
    btns.forEach(function (btn, i) {
      btn.addEventListener("click", function () {
        btns.forEach(function (b) { b.classList.remove("active"); });
        panes.forEach(function (p) { p.classList.remove("active"); });
        btn.classList.add("active");
        panes[i].classList.add("active");
        /* restart the pane entrance animation */
        panes[i].style.animation = "none";
        void panes[i].offsetWidth;
        panes[i].style.animation = "";
      });
    });
  });

  /* 8 — copy buttons on terminal windows (injected into .term-bar) */
  document.querySelectorAll(".term").forEach(function (term) {
    var bar = term.querySelector(".term-bar");
    var body = term.querySelector(".term-body");
    if (!bar || !body || bar.querySelector(".copy-btn")) return;
    var btn = document.createElement("button");
    btn.className = "copy-btn";
    btn.type = "button";
    btn.textContent = "Copy";
    btn.addEventListener("click", function () {
      var text = body.innerText.replace(/\n{3,}/g, "\n\n").trim();
      var done = function (ok) {
        btn.textContent = ok ? "Copied!" : "Select + Ctrl+C";
        btn.classList.toggle("copied", !!ok);
        window.setTimeout(function () {
          btn.textContent = "Copy";
          btn.classList.remove("copied");
        }, 1400);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(function () { done(true); },
                                                 function () { done(false); });
      } else {
        var ta = document.createElement("textarea");
        ta.value = text;
        ta.style.position = "fixed";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        var ok = false;
        try { ok = document.execCommand("copy"); } catch (err) { ok = false; }
        document.body.removeChild(ta);
        done(ok);
      }
    });
    bar.appendChild(btn);
  });

  /* 9 — docs scrollspy (left nav + right toc highlight while reading) */
  if (document.querySelector(".docs-shell")) {
    var links = {};
    document.querySelectorAll('.docs-nav a[href^="#"], .docs-toc a[href^="#"]')
      .forEach(function (a) {
        var id = a.getAttribute("href").slice(1);
        (links[id] = links[id] || []).push(a);
      });
    var setActive = function (id) {
      Object.keys(links).forEach(function (k) {
        links[k].forEach(function (a) {
          a.classList.toggle("active", k === id);
        });
      });
    };
    var sections = Object.keys(links)
      .map(function (id) { return document.getElementById(id); })
      .filter(Boolean);
    var ticking = false;
    var onSpy = function () {
      ticking = false;
      var line = window.innerHeight * 0.3;
      var cur = null;
      sections.forEach(function (s) {
        if (s.getBoundingClientRect().top <= line) cur = s.id;
      });
      if (cur) setActive(cur);
    };
    window.addEventListener("scroll", function () {
      if (!ticking) { ticking = true; window.requestAnimationFrame(onSpy); }
    }, { passive: true });
    onSpy();
  }

  /* 10 — docs nav filter (search box injected; hidden without JS) */
  var docsNav = document.querySelector(".docs-nav");
  if (docsNav && docsNav.querySelector("a")) {
    var wrap = document.createElement("div");
    wrap.className = "docs-search";
    var input = document.createElement("input");
    input.type = "search";
    input.placeholder = "Filter sections\u2026";
    input.setAttribute("aria-label", "Filter documentation sections");
    wrap.appendChild(input);
    docsNav.insertBefore(wrap, docsNav.firstChild);
    /* index every link together with its group heading so that e.g.
       "linux" finds "Quickstart: build & boot" under the "Fundray Linux" h4 */
    var entries = [];
    var group = "";
    Array.prototype.forEach.call(docsNav.children, function (child) {
      if (child.tagName === "H4") { group = child.textContent; return; }
      if (child.tagName === "A") entries.push({ el: child, hay: (group + " " + child.textContent).toLowerCase() });
    });
    input.addEventListener("input", function () {
      var q = input.value.trim().toLowerCase();
      entries.forEach(function (en) {
        en.el.style.display = !q || en.hay.indexOf(q) !== -1 ? "" : "none";
      });
    });
  }

  /* 11 — bento card spotlight (pointer-tracking glow) */
  var fine = window.matchMedia &&
    window.matchMedia("(pointer: fine)").matches;
  if (fine && !reduced) {
    document.querySelectorAll(".b-tile").forEach(function (tile) {
      tile.addEventListener("mousemove", function (ev) {
        var r = tile.getBoundingClientRect();
        tile.style.setProperty("--mx", (ev.clientX - r.left) + "px");
        tile.style.setProperty("--my", (ev.clientY - r.top) + "px");
      });
    });
  }
})();
