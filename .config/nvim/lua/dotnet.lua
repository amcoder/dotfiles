return {

  -- Set the makeprg and errorformat for C# projects
  -- This will allow you to use :make to build your C# projects
  -- and navigate through the errors with :cnext and :cprev
  set_makeprg = function(file)
    local find_in_workspace = function(name)
      return vim.fs.find(name, {
        upward = true,
        stop = vim.fs.dirname(vim.fn.getcwd()),
        path = vim.fs.dirname(file),
      })[1]
    end

    local proj = find_in_workspace(function(name)
      return name:match('%.csproj$')
    end)
    local sln = find_in_workspace(function(name)
      return name:match('%.sln$')
    end)

    local builddir = vim.fs.dirname(sln) or vim.fs.dirname(proj) or ''

    vim.opt_local.makeprg = 'dotnet build -nologo -consoleloggerparameters:NoSummary -verbosity:quiet ' .. builddir
    vim.opt_local.errorformat = '\\ %#%f(%l\\\\\\,%c):\\ %t%[A-z]%#\\ %m\\ [%.%#]'
  end,
}
