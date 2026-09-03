-- snippets/blade.lua — `@directive` completion for Blade.
--
-- friendly-snippets ships Blade snippets under `b:` prefixes, which does not
-- help when you type `@` and expect `@foreach` to show up. These use the
-- directives themselves as the trigger; `after/ftplugin/blade.lua` adds `@` to
-- 'iskeyword' so nvim-cmp matches them.
local ok, ls = pcall(require, "luasnip")
if not ok then return end

local parse = require("luasnip.util.parser").parse_snippet

-- { trigger, body } — $0 is the cursor, ${1:…} the first tabstop.
local directives = {
  -- Control flow
  { "@if",          "@if (${1:condition})\n\t$0\n@endif" },
  { "@ifelse",      "@if (${1:condition})\n\t$2\n@else\n\t$0\n@endif" },
  { "@elseif",      "@elseif (${1:condition})\n$0" },
  { "@else",        "@else\n\t$0" },
  { "@unless",      "@unless (${1:condition})\n\t$0\n@endunless" },
  { "@isset",       "@isset (${1:$variable})\n\t$0\n@endisset" },
  { "@empty",       "@empty (${1:$variable})\n\t$0\n@endempty" },
  { "@switch",      "@switch (${1:$variable})\n\t@case (${2:value})\n\t\t$0\n\t\t@break\n\t@default\n@endswitch" },
  { "@case",        "@case (${1:value})\n\t$0\n\t@break" },
  -- Loops
  { "@foreach",     "@foreach (${1:$items} as ${2:$item})\n\t$0\n@endforeach" },
  { "@forelse",     "@forelse (${1:$items} as ${2:$item})\n\t$0\n@empty\n\t\n@endforelse" },
  { "@for",         "@for (${1:$i = 0}; ${2:$i < 10}; ${3:$i++})\n\t$0\n@endfor" },
  { "@while",       "@while (${1:condition})\n\t$0\n@endwhile" },
  { "@continue",    "@continue$0" },
  { "@break",       "@break$0" },
  -- Auth / authorisation
  { "@auth",        "@auth\n\t$0\n@endauth" },
  { "@guest",       "@guest\n\t$0\n@endguest" },
  { "@can",         "@can ('${1:ability}', ${2:$model})\n\t$0\n@endcan" },
  { "@cannot",      "@cannot ('${1:ability}', ${2:$model})\n\t$0\n@endcannot" },
  { "@canany",      "@canany (['${1:ability}'], ${2:$model})\n\t$0\n@endcanany" },
  -- Layout / structure
  { "@extends",     "@extends ('${1:layouts.app}')\n$0" },
  { "@section",     "@section ('${1:content}')\n\t$0\n@endsection" },
  { "@yield",       "@yield ('${1:content}')$0" },
  { "@push",        "@push ('${1:scripts}')\n\t$0\n@endpush" },
  { "@prepend",     "@prepend ('${1:scripts}')\n\t$0\n@endprepend" },
  { "@stack",       "@stack ('${1:scripts}')$0" },
  { "@include",     "@include ('${1:view}')$0" },
  { "@includeIf",   "@includeIf ('${1:view}')$0" },
  { "@includeWhen", "@includeWhen (${1:condition}, '${2:view}')$0" },
  { "@each",        "@each ('${1:view}', ${2:$items}, '${3:item}')$0" },
  { "@once",        "@once\n\t$0\n@endonce" },
  { "@fragment",    "@fragment ('${1:name}')\n\t$0\n@endfragment" },
  -- Components
  { "@props",       "@props ([${1:'name'}])\n$0" },
  { "@aware",       "@aware ([${1:'name'}])\n$0" },
  { "@slot",        "@slot ('${1:name}')\n\t$0\n@endslot" },
  -- Forms & assets
  { "@csrf",        "@csrf$0" },
  { "@method",      "@method ('${1:PUT}')$0" },
  { "@error",       "@error ('${1:field}')\n\t$0\n@enderror" },
  { "@class",       "@class ([${1:'class' => $condition}])$0" },
  { "@style",       "@style ([${1:'color: red' => $condition}])$0" },
  { "@checked",     "@checked (${1:condition})$0" },
  { "@selected",    "@selected (${1:condition})$0" },
  { "@disabled",    "@disabled (${1:condition})$0" },
  { "@required",    "@required (${1:condition})$0" },
  { "@vite",        "@vite (['${1:resources/js/app.js}'])$0" },
  -- Misc
  { "@php",         "@php\n\t$0\n@endphp" },
  { "@json",        "@json (${1:$data})$0" },
  { "@dd",          "@dd (${1:$value})$0" },
  { "@dump",        "@dump (${1:$value})$0" },
  { "@lang",        "@lang ('${1:key}')$0" },
  { "@session",     "@session ('${1:key}')\n\t$0\n@endsession" },
  { "@production",  "@production\n\t$0\n@endproduction" },
  { "@env",         "@env ('${1:local}')\n\t$0\n@endenv" },
  { "@verbatim",    "@verbatim\n\t$0\n@endverbatim" },
  { "@use",         "@use ('${1:App\\\\Models\\\\User}')$0" },
}

local snippets = {}
for _, directive in ipairs(directives) do
  local trigger, body = directive[1], directive[2]
  table.insert(snippets, parse({ trig = trigger, name = trigger, desc = "Blade " .. trigger }, body))
end

ls.add_snippets("blade", snippets)
