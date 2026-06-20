create or replace function app.home(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(
    pgui.doc(
      pgui.frag(
        pgui.tag('h1', '{}', pgui.text('__PGUI_APP_NAME__')),
        pgui.tag('p', '{}', pgui.text('Built with pgui.')),
        pgui.tag('p', '{}', pgui.tag('a', jsonb_build_object('href','/health'), pgui.text('Health Check')))
      ),
      '__PGUI_APP_NAME__'
    )
  );
$$;

create or replace function app.health(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(pgui.text('ok'));
$$;
