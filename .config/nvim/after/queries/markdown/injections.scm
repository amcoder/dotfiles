;extends

(fenced_code_block
  ((info_string) @_lang
    (#match? @_lang "^(cs|csharp|c#|c-sharp)\\s?"))
  (code_fence_content) @c_sharp
)
