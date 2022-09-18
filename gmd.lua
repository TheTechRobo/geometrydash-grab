-- https://stackoverflow.com/questions/40149617/split-string-with-specified-delimiter-in-lua

function table.show(t, name, indent)
  local cart    -- a container
  local autoref  -- for self references

  --[[ counts the number of elements in a table
  local function tablecount(t)
    local n = 0
    for _, _ in pairs(t) do n = n+1 end
    return n
  end
  ]]
  -- (RiciLake) returns true if the table is empty
  local function isemptytable(t) return next(t) == nil end

  local function basicSerialize (o)
    local so = tostring(o)
    if type(o) == "function" then
      local info = debug.getinfo(o, "S")
      -- info.name is nil because o is not a calling level
      if info.what == "C" then
        return string.format("%q", so .. ", C function")
      else 
        -- the information is defined through lines
        return string.format("%q", so .. ", defined in (" ..
           info.linedefined .. "-" .. info.lastlinedefined ..
           ")" .. info.source)
      end
    elseif type(o) == "number" or type(o) == "boolean" then
      return so
    else
      return string.format("%q", so)
    end
  end

  local function addtocart (value, name, indent, saved, field)
    indent = indent or ""
    saved = saved or {}
    field = field or name

    cart = cart .. indent .. field

    if type(value) ~= "table" then
      cart = cart .. " = " .. basicSerialize(value) .. ";\n"
    else
      if saved[value] then
        cart = cart .. " = {}; -- " .. saved[value] 
                .. " (self reference)\n"
        autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
      else
        saved[value] = name
        --if tablecount(value) == 0 then
        if isemptytable(value) then
          cart = cart .. " = {};\n"
        else
          cart = cart .. " = {\n"
          for k, v in pairs(value) do
            k = basicSerialize(k)
            local fname = string.format("%s[%s]", name, k)
            field = string.format("[%s]", k)
            -- three spaces between levels
            addtocart(v, fname, indent .. "  ", saved, field)
          end
          cart = cart .. indent .. "};\n"
        end
      end
    end
  end

  name = name or "__unnamed__"
  if type(t) ~= "table" then
    return name .. " = " .. basicSerialize(t)
  end
  cart, autoref = "", ""
  addtocart(t, name, indent)
  return cart .. autoref
end

function split(s, sep)
    local fields = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end
-- https://stackoverflow.com/questions/40149617/split-string-with-specified-delimiter-in-lua
--
GMD = {}
GMD["comments"] = {}

GMD.comments.mapping = {"levelID","comment","authorPlayerID","likes","dislikes","messageID","spam","authorAccountID","age","percent","modBadge","moderatorChatColor"} -- https://docs.gdprogra.me/#/resources/server/comment
GMD.comments.accing  = {"userName", nil, nil, nil, nil, nil, nil, nil, "icon", "playerColor", "playerColor2", nil, nil, "iconType", "glow", "accountID"}
print(table.show(GMD.comments.accing))


GMD["find_mapping"] = function(tab, mapping, spl)
	retern = {}
	local ndata = split(tab, spl)
	print(table.show(ndata))
	for j=1, #ndata do
		if not (j % 2 == 0) then -- key
			key = ndata[j]
			key = mapping[tonumber(key)]
		else -- value
			local value = ndata[j]
			print(key, value, j)
			retern[key] = value
		end
	end
	return retern
end

GMD["comments"]["parse"]   = function(comments)
	local comment = comments
	local splitted = split(comment, ":")
	if not splitted[2] then
		return false
	end
	local retern = {}
	retern.data = comment
	retern.comments = split(comment, "#")[1]

	retern.parsed = {account={},comment={}}
	--io.stderr:write("Split PIPE\n")
	local data = split(retern.comments, "|")
	for i=1, #data do
		local data_splitted_lol = split(data[i], ":")
		local comment_data      = data_splitted_lol[1]
		print(table.show(data_splitted_lol))
		local user_structure    = data_splitted_lol[2]
		data[i] = comment_data
		retern.parsed.comment[i] = GMD.find_mapping(comment_data, GMD.comments.mapping, "~")
		retern.parsed.account[i] = GMD.find_mapping(user_structure, GMD.comments.accing,  "~")
	end
	return retern
end
GMD["comments"]["getOneComment"] = function (self, comments, pos)
	local parsed = self.parse(comments)
	if not parsed then
		return false
	else
		return parsed.parsed.comment[pos or 1]
	end
end

GMD["level"] = {}

GMD.level.mapping = {"levelID","levelName","description","levelString","version","playerID","BAD", "difficultyDenominator", "difficultyNumerator", "downloads", "setCompletes", "officialSong", "gameVersion", "likes", "length", "dislikes", "demon", "stars", "featureScore", nil, nil, nil, nil, nil, "auto", "recordString", "password", "uploadDate", "updateDate", "copiedID", "twoPlayer", nil, nil, nil, "customSongId", "extraString", "coins", "verifiedCoins", "starsRequested", "lowDetailMode", "dailyNumber", "epic", "demonDifficulty", "isGauntlet", "objects", "editorTime", "editorTime(copies)", "settingsString"} -- https://docs.gdprogra.me/#/resources/server/level

GMD["level"]["parse"]   = function(level)
	local data = split(level, ":")
	local retern = {}

	retern.parsed = {}
	retern.parsed.level = {}
	for j=1, #data do
		if not (j % 2 == 0) then -- key
			key = data[j]
			key = GMD.level.mapping[tonumber(key)]
		else -- value
			local value = data[j]
			--io.stderr:write(j .. "\n")
			--io.stderr:write(key .. "\n")
			--io.stderr:write(value .. "\n")
			retern.parsed.level[key] = value
		end
	end
	return retern
end


function GMDtest()
	io.stderr:write("Starting CheckShitWorks for Item\n")
	local strin = "2~aSBoYWNrZWQgdGhpcyBjb21tZW50IHlvdSBDYW50IGxpa2UgaXQgdHJ5~3~19471884~4~6~7~0~10~0~9~1 year~6~77248124:1~ZeHx~9~30~10~6~11~12~14~0~15~2~16~13878463|2~aSBoYWNrZWQgdGhpcyBjb21lbnQgc28geW91IGNhbnQgbGlrZSBpdA==~3~135815080~4~6~7~0~10~100~9~1 year~6~77417227:1~icedvortex8~9~14~10~18~11~12~14~4~15~0~16~13884663|2~bGlrZSBpZiB5b3UgcGxhaW5nIGluIDIwMjA=~3~13851611~4~6~7~0~10~0~9~1 year~6~77446479:1~ThePiratus~9~1~10~0~11~3~14~0~15~0~16~6405061|2~bGlrZSB0aGlzIGNvbW1lbnQgZm9yIGZyZWUgcGl6emE=~3~125818615~4~6~7~0~10~100~9~1 year~6~77581516:1~Valuable~9~133~10~15~11~12~14~0~15~0~16~13270355|2~TGlrZSBpZiB5b3UgYXJlIG5vdCBnYXk=~3~134744376~4~6~7~0~10~100~9~1 year~6~77586360:1~WEEEEEEEEEEEEED~9~1~10~0~11~3~14~0~15~0~16~13792723|2~c29tZW9uZSBjYW4gbGlrZSBteSBjb21lbnRzPw==~3~13968849~4~6~7~0~10~100~9~1 year~6~77631193:1~Alv0854~9~133~10~18~11~12~14~0~15~2~16~5185523|2~ZGlzbGlrZSBpZiB5b3UgYXJlIGdheQ==~3~126764501~4~6~7~0~10~0~9~1 year~6~77640970:1~MinkyBoy69~9~103~10~15~11~15~14~0~15~2~16~13519048|2~VGhpcyBjb21tZW50IGlzIGhhY2tlZCBzbyB0aGF0IGlmIHlvdSBsaWtlIGl0IHRoZSBudW1iZXIgbmV4dCB0aGUgdGhlIGxpa2UgYnV0dG9uIHdpbGwgZ28gdXAgOCk=~3~97601741~4~6~7~0~10~0~9~1 year~6~77759987:1~Bokogoblin~9~127~10~36~11~3~14~0~15~0~16~10470776|2~bGlrZSBpZiB5b3Ugd2FudCB0byBjb21wbGV0ZSBuaW5lIGNpcmNsZXMgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIA==~3~61823116~4~6~7~0~10~100~9~1 year~6~77813533:1~samurai58~9~133~10~33~11~6~14~0~15~0~16~8251729|2~bGlrZSB0aGlzIGNvbW1lbnQ=~3~125711065~4~6~7~0~10~100~9~1 year~6~77903131:1~mikeneverbejoe~9~142~10~39~11~12~14~0~15~2~16~13558999#88788:1250:10"
	assert(GMD["comments"]:getOneComment(strin)["comment"] == "aSBoYWNrZWQgdGhpcyBjb21tZW50IHlvdSBDYW50IGxpa2UgaXQgdHJ5")
	assert(not GMD["comments"]:getOneComment("-1"))

	assert(GMD["level"]["parse"]("1:6508283:2:ReTraY:3:VGhhbmtzIGZvciBwbGF5aW5nIEdlb21ldHJ5IERhc2g=:4:{levelString}:5:3:6:4993756:8:10:9:10:10:39431612:12:0:13:21:14:4125578:17::43:3:25::18:2:19:7730:42:0:45:20000:15:3:30:0:31:0:28:5 years:29:1 year:35:557117:36:0_733_0_0_0_0_574_716_0_0_352_78_729_0_42_0_833_68_0_347_0_38_240_205_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0_0:37:3:38:1:39:2:46:7729:47:13773:40:0:27:AwMABAYDBw==#eb541c03f8355c0709f8007a1d9a595ae5bedc5d#291568b26b08d70a198fca10a87c736a2823be0c").parsed.level["levelID"] == "6508283")
	io.stderr:write("Finished CheckShitWorks for Item\n")
end
GMDtest()
