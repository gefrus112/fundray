/* Fundray site.js — progressive enhancement only.
   The site is fully usable without JavaScript; this file adds:
   1. Scroll-reveal animations (IntersectionObserver)
   2. The before/after compare slider drag logic
   3. Subtle header elevation on scroll
*/
(function () {
  "use strict";

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
})();
