/**
 * Usman Engineer Analytics - Ultra-Light Client Tracker (<1 KB)
 * Privacy-friendly: No cookies, no personal data, non-blocking beacon.
 */
(function() {
  'use strict';

  // Respect opt-out (e.g., site owner excluding own visits)
  if (localStorage.getItem('usman_analytics_optout') === '1') return;
  if (sessionStorage.getItem('usman_admin_active') === '1') return;

  // Don't track localhost unless explicitly debugging
  var host = window.location.hostname;
  var isLocal = host === 'localhost' || host === '127.0.0.1' || host.indexOf('192.168.') === 0;
  if (isLocal && window.location.search.indexOf('track_debug=1') === -1) return;

  function getDevice() {
    var w = window.innerWidth;
    if (w < 768) return 'Mobile';
    if (w <= 1024) return 'Tablet';
    return 'Desktop';
  }

  function getReferrer() {
    var ref = document.referrer;
    if (!ref) return 'Direct';
    try {
      var url = new URL(ref);
      if (url.hostname === window.location.hostname) return 'Internal';
      return url.hostname.replace(/^www\./, '');
    } catch (e) {
      return 'Direct';
    }
  }

  function send(data) {
    var payload = JSON.stringify(data);
    var url = '/api/track';

    if (navigator.sendBeacon) {
      navigator.sendBeacon(url, payload);
    } else {
      fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: payload,
        keepalive: true
      }).catch(function() {});
    }
  }

  // Track page view
  var pageData = {
    type: 'pageview',
    path: window.location.pathname || '/',
    referrer: getReferrer(),
    screen: getDevice()
  };

  // Run on initial load
  if (document.readyState === 'complete') {
    send(pageData);
  } else {
    window.addEventListener('load', function() { send(pageData); });
  }

  // Custom Event Tracker helper exposed to window
  window.trackEvent = function(name, extra) {
    if (localStorage.getItem('usman_analytics_optout') === '1') return;
    send({
      type: 'event',
      event: name,
      path: window.location.pathname || '/',
      extra: extra || null
    });
  };

  // Auto-bind click events on elements with data-track attribute
  document.addEventListener('click', function(e) {
    var el = e.target.closest('[data-track]');
    if (el) {
      var eventName = el.getAttribute('data-track');
      if (eventName) {
        window.trackEvent(eventName);
      }
    }
  }, { passive: true });
})();
