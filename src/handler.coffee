###
# LemonLDAP::NG handler for Node.js/express
#
# See README.md for license and copyright
###
conf          = null
cookieDetect  = null

exports.init = (args) ->
	conf          = require('./handlerConf').init(args)
	cookieDetect  = new RegExp "\\b#{conf.tsv.cookieName}=([^;]+)"
	exports

exports.run = (req, res, next) ->
	vhost = req.headers.host
	# TODO: detect https
	uri = decodeURI req.url
	if conf.tsv.maintenance[vhost]
		# TODO
		console.log 'TODO'

	# CDA: TODO
	if conf.tsv.cda and uri.replace(new RegExp("[\\?&;](#{cn}(http)?=\\w+)$",'','i'))
		str = RegExp.$1
		# TODO redirect with cookie

	protection = isUnprotected req, uri

	if protection == 'skip'
		# TODO: verify this
		return next()

	id = fetchId(req)
	if id
		session = retrieveSession(id)
		if session
			unless grant req, uri, session
				return forbidden req, res, session
			sendHeaders req, session
			return next()

	if protection == 'unprotect'
		# TODO: status, log ?
		return next()

	return goToPortal res, 'http://' + vhost + uri

grant = (req, uri, session) ->
	vhost = resolveAlias req
	unless conf.tsv.defaultCondition[vhost]?
		console.log "No configuration found for #{vhost}"
		return false
	for rule,i in conf.tsv.locationRegexp[vhost]
		if uri.match rule
			return conf.tsv.locationCondition[vhost][i](session)
	return conf.tsv.defaultCondition[vhost](session)

forbidden = (req, res, session) ->
	uri = req.uri
	if u = conf.datas._logout
		return goToPortal res, u, 'logout=1'
	res.status(403).send('Forbidden')

sendHeaders = (req, session) ->
	vhost = resolveAlias req
	try
		for k,v of conf.tsv.forgeHeaders[vhost](session)
			req.headers[k] = v
			req.rawHeaders.push k, v
	catch err
		console.log "No headers configuration found for #{vhost}"
	true

goToPortal = (res, uri, args) ->
	urlc = conf.tsv.portal()
	if uri
		urlc += '?url=' + new Buffer(encodeURI(uri)).toString('base64')
	if args
		urlc += if uri then '&' else '?'
		urlc += args
	res.redirect urlc

resolveAlias = (req) ->
	vhost = req.headers.host.replace /:.*$/, ''
	return conf.tsv.vhostAlias[vhost] || vhost

fetchId = (req) ->
	if req.headers.cookie
		cor = cookieDetect.exec req.headers.cookie
		if cor and cor[1]
			return cor[1]
	else
		return false

retrieveSession = (id) ->
	session = conf.sa.get id
	unless session
		console.log "Session #{id} can't be found in store"
		return null
	return session

isUnprotected = (req, uri) ->
	vhost = resolveAlias req
	unless conf.tsv.defaultCondition[vhost]?
		return false
	for rule,i in conf.tsv.locationRegexp[vhost]
		if uri.match rule
			return conf.tsv.locationProtection[vhost][i]
	return conf.tsv.defaultProtection[vhost]