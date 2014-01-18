#!/usr/bin/env rdmd

import std.exception;
import std.file;
import std.path;
import std.process;
import std.stdio;
import std.string;

string resolveRedirect(string url)
{
	auto result = execute(["curl", "--head", url]);
	enforce(result.status == 0, "curl failed");
	auto lines = result.output.splitLines();
	foreach (line; lines)
		if (line.startsWith("Location: "))
			return line["Location: ".length .. $];
	throw new Exception("Not a redirect: " ~ lines[0]);
}

void download(string url, string target)
{
	if (target.exists)
		return; // already downloaded
	auto path = target.dirName;
	if (!path.exists)
		mkdirRecurse(path);

	auto temp = target ~ ".temp";
	scope(failure) if (temp.exists) temp.remove();
	stderr.writeln("Downloading: ", url);
	auto status = spawnProcess(["curl", "--output", temp, url]).wait();
	enforce(status == 0, "curl failed");
	rename(temp, target);
}

/// Downloads the file at url to dir.
/// Returns the path to the downloaded file.
string downloadTo(string url, string dir)
{
	auto fn = url.split("/")[$-1];
	auto target = buildPath(dir, fn);
	download(url, target);
	return target;
}

/// Invokes 7z to unpack the give archive to the
/// given directory, if it doesn't already exist.
void unpackTo(string archive, string dir)
{
	if (dir.exists)
		return;
	auto temp = dir ~ ".temp";
	if (temp.exists)
		temp.rmdirRecurse();
	scope(failure) if (temp.exists) temp.rmdirRecurse();
	mkdirRecurse(temp);
	stderr.writeln("Extracting ", archive, " to ", dir);
	auto status = spawnProcess(["7z", "x", "-o" ~ temp, archive]).wait();
	enforce(status == 0, "7z failed");
	rename(temp, dir);
}

const downloadDir = "downloads";

string msdl(int n, string dir=downloadDir)
{
	string url = "http://go.microsoft.com/fwlink/?LinkId=%d&clcid=0x409".format(n);
	url = url.resolveRedirect();
	return url.downloadTo(dir);
}

void prepareWiX()
{
	// CodePlex does not provide a direct download link
	const url = "http://dump.thecybershadow.net/f1cbea894216f483f335f6fcaa544c30/wix38-binaries.zip";
	auto archive = url.downloadTo(downloadDir);
	archive.unpackTo("wix");
}

string[string] wineEnv;
static this()
{
	wineEnv["WINEPREFIX"] = "wine".absolutePath();
}

string decompileMSI(string msi)
{
	string target = msi.setExtension(".wxs");
	if (target.exists)
		return target;

	auto temp = target ~ ".temp";
	if (temp.exists) temp.remove();
	scope(failure) if (temp.exists) temp.remove();

	stderr.writeln("Decompiling ", msi, " to ", target);
	auto status = spawnProcess(["wine", "wix/dark.exe", msi, "-o", temp], wineEnv).wait();
	enforce(status == 0, "wine wix/dark failed");
	rename(temp, target);
	return target;
}

struct VS
{
	int[] downloads;
}

void installVS(in VS vs)
{
	string[] cabs, msis;
	foreach (dl; vs.downloads)
	{
		auto fn = msdl(dl);
		switch (fn.extension.toLower())
		{
			case ".cab":
				cabs ~= fn;
				break;
			case ".msi":
				msis ~= fn;
				break;
			default:
				throw new Exception("Unexpected file extension: " ~ fn);
		}
	}

	foreach (cab; cabs)
		cab.unpackTo(cab.stripExtension);
	foreach (msi; msis)
	{
		string wxs = msi.decompileMSI();
	}
}

const VS VS2010 =
{
	downloads : [318460, 318461],
};

void main(string[] args)
{
	stderr.writeln("Far CI setup script");
	stderr.writeln("Written by Vladimir Panteleev <vladimir@thecybershadow.net>");
	stderr.writeln();

	prepareWiX();

	installVS(VS2010);
}
