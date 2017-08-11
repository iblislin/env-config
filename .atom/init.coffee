vimNormalToEnd = () ->
    editor = atom.workspace.getActiveTextEditor()
    view = atom.views.getView editor
    atom.commands.dispatch view, 'vim-mode-plus:move-to-last-character-of-line'

atom.commands.add 'atom-workspace',
    'custom:break-autocomplete-pluse-or-end-of-file': ->
        pkg = atom.packages.getLoadedPackage 'autocomplete-plus'
        if pkg == undefined
            return vimNormalToEnd()

        s = pkg.mainModule.autocompleteManager.suggestionList
        if s == null
            return vimNormalToEnd()

        if s.isActive()
            editor = atom.workspace.getActiveTextEditor()
            view = atom.views.getView editor
            atom.commands.dispatch view, 'autocomplete-plus:cancel' 
        else
            vimNormalToEnd()
