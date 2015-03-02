CoffeeScript = require('coffee-script')
path = require('path')

module.exports = new class Processor
    # Fake requires for me to verify coffee-links as I work on it.
    _testRequire: ->
        require('./same')
        require('../parent')
        require('./something.coffee')
        require('sub-atom')
        # This will jump up to module.exports
        require('./processor')

    scopes: [
        'source.coffee'
        'source.coffee.jsx'
    ]

    process: (source) ->
        links = []
        try
            node = CoffeeScript.nodes(source)
            links = @_processNode(node)
        return links

    followLink: (srcFilename, { moduleName }) ->
        # This is the same order they're listed in CoffeeScript.
        coffeeExtensions = ['.coffee', '.litcoffee', '.coffee.md']
        basedir = path.dirname(srcFilename)
        try
            resolved = this._resolve(moduleName, {
                basedir: basedir,
                extensions: [ '.js', coffeeExtensions...]
            })

            # If it resolves but isn't a path it's probably a built
            # in node module.
            if resolved is moduleName
                return "http://nodejs.org/api/#{moduleName}.html"
            return resolved

        # Allow linking to relative files that don't exist yet.
        if moduleName[0] is '.'
            return moduleName

    scanForDestination: (source, marker) ->
        for lineNum, line of source.split("\n")
            if line.indexOf('module.exports') != -1
                return [
                    lineNum
                    line.indexOf('module.exports')
                ]
        return undefined

    # Attached to the object so it can be mocked for tests
    _resolve: (modulePath, options) ->
        resolve = require('resolve').sync
        return resolve(modulePath, options)

    _processNode: (node, links = []) ->
        nodeName = (node) ->
            node?.base?.value

        # nodes don't always provide a name, so .isNew indicates that this
        # is probably a Call node.
        if node.isNew? and nodeName(node.variable) is 'require' and
                node.args?.length is 1

            { locationData } = node.args[0]
            links.push({
                # [1...-1] trims the quote characters
                moduleName: nodeName(node.args[0])[1...-1]
                range: [
                    [ locationData.first_line, locationData.first_column ],
                    [ locationData.last_line, locationData.last_column ]
                ]
            })

        node.eachChild (child) =>
            links = links.concat(@_processNode(child))

        return links
