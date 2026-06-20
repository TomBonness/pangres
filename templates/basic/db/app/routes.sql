-- Demo-only reset: clears the Omnigres default/demo routes before registering the guestbook. Do not use this file in an existing app with unrelated routes.
delete from omni_httpd.urlpattern_router;
call pgui.route('/',       'app.home');
call pgui.route('/health', 'app.health');
