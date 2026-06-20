-- One <article> per message; author/body escaped via pgui.text(); per-row htmx delete button.
create or replace function app.guestbook_list() returns pgui.html language sql stable as $$
  select case when count(*) = 0 then
    pgui.tag('p','{}', pgui.text('No messages yet.'))
  else
    pgui.frag(variadic array_agg(
      pgui.tag('article','{}',
        pgui.tag('header','{}',
          pgui.text(g.author||' · '||to_char(g.created_at,'HH24:MI:SS'))),
        pgui.text(g.body),
        pgui.tag('button',
          jsonb_build_object('class','secondary','hx-post','/messages/delete',
            'hx-vals', json_build_object('id', g.id)::text,
            'hx-target','#list','hx-swap','innerHTML'),
          pgui.text('delete'))
      ) order by g.id desc))
  end
  from app.guestbook g;
$$;

-- GET /  -> full page: post form + live-polling list container.
create or replace function app.home(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language sql as $$
  select pgui.respond_html(pgui.doc(
    pgui.frag(
      pgui.tag('h1','{}', pgui.text('pgui guestbook — served by Postgres')),
      pgui.tag('form',
        jsonb_build_object('hx-post','/messages','hx-target','#list','hx-swap','innerHTML',
                           'hx-on::after-request','this.reset()'),
        pgui.tag('input', jsonb_build_object('name','author','placeholder','name')),
        pgui.tag('input', jsonb_build_object('name','body','placeholder','message','required','')),
        pgui.tag('button', jsonb_build_object('type','submit'), pgui.text('Post'))),
      pgui.tag('div',
        jsonb_build_object('id','list','hx-get','/messages',
                           'hx-trigger','load, every 3s','hx-swap','innerHTML'),
        app.guestbook_list())),
    'pgui guestbook'));
$$;

-- /messages : GET returns the list fragment; POST inserts then returns it.
create or replace function app.messages(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language plpgsql as $$
declare _author text; _body text;
begin
  if upper(request.method::text) = 'POST' then
    _author := coalesce(nullif(trim(pgui.form(request,'author')),''),'anon');
    _body   := nullif(trim(pgui.form(request,'body')),'');
    if _body is not null then
      insert into app.guestbook(author, body) values (_author, _body);
    end if;
  end if;
  return pgui.respond_html(app.guestbook_list());
end$$;

-- POST /messages/delete : delete by id, return refreshed list fragment.
create or replace function app.delete_message(request omni_httpd.http_request)
  returns omni_httpd.http_outcome language plpgsql as $$
begin
  delete from app.guestbook where id = (nullif(trim(pgui.form(request,'id')),''))::bigint;
  return pgui.respond_html(app.guestbook_list());
exception when invalid_text_representation then            -- missing/non-numeric id
  return pgui.respond_html(app.guestbook_list());
end$$;
