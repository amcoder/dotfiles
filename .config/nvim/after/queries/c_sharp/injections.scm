; extends
((raw_string_literal) @injection.content
  (#match? @injection.content "^\"\"\"\n?\\s*\\<([a-zA-Z0-9]+|\\?xml)")
  (#offset! @injection.content 0 3 0 -3)
  (#set! injection.language "xml"))

(object_creation_expression
    type: (identifier) @type (#eq? @type "Regex")
    arguments: (argument_list
      .
      (argument
        .
          (verbatim_string_literal) @injection.content
          (#offset! @injection.content 0 2 0 -1)
          (#set! injection.language "regex"))))

(attribute
  name: (identifier) @attribute (#eq? @attribute "GeneratedRegex")
  (attribute_argument_list
    .
    (attribute_argument
      .
        (verbatim_string_literal) @injection.content
        (#offset! @injection.content 0 2 0 -1)
        (#set! injection.language "regex"))))

(invocation_expression
  function: (member_access_expression
    name: (identifier) @function (#eq? @function "Match"))
  arguments: (argument_list
    (argument)
    (argument
      .
        (verbatim_string_literal) @injection.content
        (#offset! @injection.content 0 2 0 -1)
        (#set! injection.language "regex"))))
