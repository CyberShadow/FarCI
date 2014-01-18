#!/usr/bin/env rdmd
// rdmd -L--static -L-lphobos2 -L-Bdynamic -L-lcurl

import std.exception;
import std.file;
import std.net.curl;
import std.path;
import std.process;
import std.stdio;
import std.string;

string msdl(int n, string where="")
{
	
	string url = "http://go.microsoft.com/fwlink/?LinkId=%d&clcid=0x409".format(n);
	auto http = HTTP(url);
	string fileUrl;
	http.onReceiveHeader =
		(in char[] key, in char[] value) { if (!key.icmp("Location")) fileUrl = value.idup; };
	http.onReceive = (ubyte[] data) { /+ drop +/ return data.length; };
	http.perform();
	enforce(fileUrl, "Redirect failed");

	stderr.writeln("Downloading: ", url);
	auto fn = url.split("/")[$-1];
	auto target = buildPath(where, fn);
	mkdirRecurse(target.dirName);
	/+
	f = open(target, "wb")
	f. .write(u)
	#u.info()
	#urllib.urlretrieve(url, filename, reporthook, data)
	return target
	+/
	return target;
}

void main(string[] args)
{
	stderr.writeln("Far CI setup script");
	stderr.writeln("Written by Vladimir Panteleev <vladimir@thecybershadow.net>");
	stderr.writeln();

	writeln(msdl(318461));
}
