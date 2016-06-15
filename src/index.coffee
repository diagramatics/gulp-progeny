gutil = require('gulp-util')
through = require('through2')
sysPath = require('path')
fs = require('fs')
progeny = require('progeny')

depCache = {}
processedFileNames = {}

makeFile = (path, type, base, cwd) ->
	file = new gutil.File({
		base: base
		cwd: cwd
		path: path
		stat: fs.statSync(path)
	})
	if type is 'stream'
		file.contents = fs.createReadStream(path)
	else
		file.contents = fs.readFileSync(path)
	file


initParseConfig = (config) ->
	parser = progeny(config)
	(path, cb) ->
		# clear old dependencies
		Object.keys(depCache).forEach (key) ->
			if path of depCache[key]
				delete depCache[key][path]

		parser path, (err, deps) ->
			deps = deps.filter(fs.existsSync)
			deps.forEach((dep) ->
					depCache[dep] ?= {}
					depCache[dep][path] = 1
				)

			cb()

pushFileRecursive = (fileSet, path) ->
	cache = (depCache[path] ?= {})
	# refresh cache
	for childPath of cache
		if !fs.existsSync(childPath)
			delete cache[childPath]
		else
			fileSet[childPath] = 1
			pushFileRecursive(fileSet, childPath)

module.exports = (config) ->
	getDeps = initParseConfig(config)
	return through.obj (file, enc, cb) ->
		self = this

		if file.isNull()
			@push(file)
			return cb()

		path = file.path
		type = file.isStream() ? 'stream' : 'buffer'
		cwd = file.cwd
		base = file.base
		@push(file)

		onDepsParsed = ->
			# do nothing when start up
			if !processedFileNames[path]
				processedFileNames[path] = 1
				return cb()
			fileSet = {}
			pushFileRecursive(fileSet, path)
			for childPath of fileSet
				self.push(makeFile(childPath, type, base, cwd))
			cb()

		getDeps path, onDepsParsed
