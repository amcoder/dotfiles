; extends
((raw_string_literal) @injection.content
  (#match? @injection.content "^\"\"\"\n\\s*\\<([a-zA-Z0-9]+|\\?xml)")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.language "xml"))
