small-ish things:
add opts to the compiler and store some basic state in it (like parent node and stuff)

when rendering h() check to see if there are classes/or an id, and render into the shorthand form
eg. h('div',{id:'cool',c:['lala','hoho']}) -> h('div#cool.lala.hoho')


integrate into phoenix a simple html page, then compiles the template into js

create mapping from templates into roadtrip configuration
 -> templates are kinda like 'pages' and components are different things inside the templates

top-level templates/fragments get converted to functions with (assigns/d) and `@value` expands to assigns.value

`@value` is a server-side variable, and `$value` is a client-side variable

------------------------

[ 0:00:00 ] | [combo]
  [snooze]  | [list]
 [settings] | -------

combo should emulate the gmail new label combobox (with the new text field n'stuff)

for settings, add ability to edit sounds as well as the pomodoro settings
