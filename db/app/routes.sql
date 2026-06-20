-- Demo-only reset: clears the Omnigres default/demo routes before registering the guestbook. Do not use this file in an existing app with unrelated routes.
delete from omni_httpd.urlpattern_router;          -- drop the Omnigres default page route
call pgui.route('/',                'app.home');
call pgui.route('/messages',        'app.messages');
call pgui.route('/messages/delete', 'app.delete_message');
