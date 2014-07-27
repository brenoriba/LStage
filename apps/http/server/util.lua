local M={}

local server_version="Lstage webserver 1.0"

function M.response_headers ()
	local t={
		Date = os.date ("!%a, %d %b %Y %H:%M:%S GMT"),
		Server = server_version,
		--Connection = 'close'
	}
	return t
end

local status_code={
	[200]="OK",
	[404]="File not found",
	[405]="Method Not Allowed",
}

function M.stdresp(res)
	local ret={"HTTP/1.1 " ..res.status_code.." "..status_code[res.status_code].."\r\n"}
	for k,v in pairs(res.headers) do
		table.insert(ret,k..": "..v.."\r\n")
	end
	table.insert(ret,"\r\n")
	return table.concat(ret)
end

return M

