require "sinatra"
require "redis"
require "json"
require_relative "anyBase"

def getTitle(doc)
	firstLine = doc.strip[/^[^\n]+(?=\n|$)/]
	firstLine.length <= TITLE_LENGTH ? firstLine : firstLine[0,TITLE_LENGTH-3]+"..."
end

configure do
	#set the base string we'll use for converting from base 10
	BASE_62 = ("0".."9").to_a.join("")+("a".."z").to_a.join("")+("A".."Z").to_a.join("")
	#define our Redis instance (params from Heroku getting started)
	uri = URI.parse("redis://SituatedBanana:fcfa73afd9670528dde35516b026f4dd@carp.redistogo.com:9422/")
  	REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
	REDIS.select 0
	REDIS.setnx "_id", 0
	#set the default page title, that is, if @title is never set
	DEFAULT_TITLE = "docdock | The Dock for Docs"
	#set the title appendage so that the final title looks like @title+TITLE_APPENDAGE
	TITLE_APPENDAGE = " | docdock"
	#max characters of doc to show as the title
	TITLE_LENGTH = 64
	#number of recent docs to show
	RECENT_DOCS = 30
	set :public_folder, File.dirname(__FILE__)+"/../public"
end

get "/*" do
	if params[:splat][0] != ""
		@doc = REDIS.get params[:splat][0]
		unless @doc
			redirect "/"
		end
		@title = getTitle @doc
	end
	lastId = REDIS.get("_id").to_i
	@recentDocs = []
	RECENT_DOCS.times do |i|
		id = lastId-i
		if id > 0
			idBase62 = id.b BASE_62
			@recentDocs << { id: idBase62, doc: getTitle(REDIS.get(idBase62)) }
		else
			break
		end
	end
	erb :index
end

post "*" do
	response = {status: "missing param"}
	if params["doc"]
		if params["doc"].strip == ""
			response["status"] = "doc empty"
		else
			id = REDIS.get "_id"
			unless REDIS.get(id) == params["doc"]
				id = REDIS.incr "_id"
				REDIS.set id.b(BASE_62), params["doc"]
			end
			response["status"] = id
		end
	end
	JSON.generate response
end