require "gmd"

NEW_ITEMS = {}

-- Reads an entire file
function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end

-- Check if text starts with a prefix
function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

-- We don't need to repeatedly archive the echo server
wget.callbacks.write_to_warc = function(url, http_stat)
	if startswith(url.url, "http://thetechrobo.ca:1337/") then
		return false
	end
	return true
end

wget.callbacks.httploop_result = function(url, err, http_stat)
	if startswith(url.url, "http://thetechrobo.ca:1337/") then
		return wget.actions.NOTHING
	end
	local data = readAll(http_stat.local_file)
	if data == "-1" then
		io.stderr:write("The GD servers returned an invalid response.\n")
		io.stderr:write("Dump:\n")
		local dump = http_stat
		dump.err = true
		dump.data = data
		io.stderr:write(table.show(dump))
		return wget.actions.CONTINUE
	end
	local statuscode = http_stat["statcode"]
	if statuscode == 500 then
		return wget.actions.CONTINUE
	end
	return wget.actions.NOTHING
	-- Time to make sure that it's a valid response.
--	if startswith(url["url"], "http://www.boomlings.com/database/getGJComments21.php") then
--		local result = GMD.comments.parse(data)
--		if result then
--			return wget.actions.NOTHING
--		else
--			io.stderr:write("\aYou've been IP-banned from Geometry Dash's servers. Sorry about that.\n")
--			io.stderr:write("Please let us know in #geometrytrash on hackint!\n")
--			io.stderr:write("Sleeping 69420 seconds. (nice)\n")
--			os.execute("sleep 69420")
--			return wget.actions.ABORT -- We've been banned
--		end
--	end
end

local PAGES_DONE = {}

wget.callbacks.get_urls = function(file, url, is_css, iri)
	local addedUrls = {}
	if startswith(url, "http://www.boomlings.com/database/downloadGJLevel22.php") then
		-- extract player ID here, and add to discovered items list
		-- also add the song URL to queue if it's hosted on RobTop's servers
		  -- (and hasn't been downloaded already)
		-- (newgrounds is a biiiiit too big)
	end
	if startswith(url, "http://www.boomlings.com/database/getGJComments21.php") then
		-- Todo: Extract acc ID and add to queue
		local data = readAll(file)
		if data == "error code: 1020" then
			return
		end
		if data == "" then
			return
		end
		local splits = split(data, "#") -- total:offset:commentsPerPage (thanks to Yessy#1984)
		if not splits[2] then
			splits[2] = splits[1]
		end
		local splitted = splits[2]
		local splittedAgain = split(splitted, ":")
		local cpp = splittedAgain[3]
		local currentPage = math.ceil(splittedAgain[2] / cpp)
		if PAGES_DONE[currentPage] then
			return {}
		end
		PAGES_DONE[currentPage] = true
		local totalPages =  math.ceil(splittedAgain[1] / cpp)
		if currentPage < totalPages then
			local nextPage = currentPage + 1
			local comment_post = "levelID=" .. ItemThingy .. "&page=" .. nextPage.. "&secret=Wmfd2893gb7&gameVersion=21&binaryVersion=35&gdw=0&mode="
			local headers = {Referer="A script"} -- cloudflare is idiotic lmao
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJComments21.php", post_data=comment_post .. "0", headers=headers })
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJComments21.php", post_data=comment_post .. "1", headers=headers })
		end
	end
	if startswith(url, "http://thetechrobo.ca:1337/") then
		local data = readAll(file)
		assert((startswith(data, "level:") or startswith(data, "songmeta:")), "Invalid item type")
		local otherdata = split(data, ":")
		ItemThingy = otherdata[2] -- set the item for later use globally
		if otherdata[1] == "songmeta" then
			local pd = "songID=" .. otherdata[2] .. "&secret=Wmfd2893gb7"
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJSongInfo.php", post_data=pd})
		end
		if otherdata[1] == "level" then
			local pd = "levelID=" .. otherdata[2] .. "&secret=Wmfd2893gb7"
			-- Queue level download
			table.insert(addedUrls, { url="http://www.boomlings.com/database/downloadGJLevel22.php", post_data=pd})
			-- Queue level search results
			local opd = "str=" .. otherdata[2] .. "&type=0&page=0&secret=Wmfd2893gb7"
			local opd2 = "str=" .. otherdata[2] .. "&type=2&page=0&secret=Wmfd2893gb7"
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJLevels21.php", post_data=opd }) -- search
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJLevels21.php", post_data=opd2}) -- search with type=2
			-- queue comments
			local comment_post = "levelID=" .. otherdata[2] .. "&page=0&secret=Wmfd2893gb7&gameVersion=21&binaryVersion=35&gdw=0&mode="
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJComments21.php", post_data=comment_post .. "0"})
			table.insert(addedUrls, { url="http://www.boomlings.com/database/getGJComments21.php", post_data=comment_post .. "1"})
		end
	end
	io.stderr:write(table.show(addedUrls))
	return addedUrls
end
