module preppy;

import std.stdio;
import std.string;
import std.array;
import std.algorithm;
import std.getopt;
import std.conv;
import std.exception;
import std.file;

enum PreprocessorDirective
{
    None,
    Ifdef,
    Elseif,
    Else
}

string[] preprocess(string[] lines, string[] defines = [], string[] includePaths = [
])
{
    string[] parsedIncludes;
    string[] output;
    PreprocessorDirective[] currentDirective = [PreprocessorDirective.None];

    bool includeHappened;
    do
    {
        parsedIncludes = [];
        includeHappened = false;
        foreach (line; lines)
        {
            string stripped = line.strip();
            if (stripped.canFind("#include"))
            {
                string filePath = stripped.split("#include ")[1].replace(`"`, "");
                parsedIncludes ~= readText(filePath).split("\n");
                includeHappened = true;
            }
            else
            {
                parsedIncludes ~= line;
            }
        }
        lines = parsedIncludes;
    }
    while (includeHappened);

    bool[] activeBlock = [true];
    foreach (line; lines)
    {
        string stripped = line.strip();

        if (activeBlock.all() && stripped.canFind("#define"))
        {
            auto tokens = stripped.split("#define ");
            if (tokens.length == 1)
            {
                throw new Exception("#define indentifier not specified");
            }
            if (tokens.length == 2)
            {
                string defineName = tokens[1];
                defines ~= defineName;
            }
            if (tokens.length > 2)
            {
                throw new Exception("#define expressions/values are not supported");
            }
            continue;
        }

        if (stripped.canFind("#ifdef"))
        {
            string defineName = stripped.split("#ifdef ")[1];

            if (!activeBlock.all())
            {
                activeBlock ~= false;
            }
            else
            {
                activeBlock ~= defines.canFind(defineName);
            }
            currentDirective ~= PreprocessorDirective.Ifdef;
            continue;
        }

        if (stripped.canFind("#elseif"))
        {
            stripped = stripped.replace("#elseif", "#elif");
        }

        if (stripped.canFind("#elif"))
        {
            if (currentDirective[$ - 1] != PreprocessorDirective.Ifdef)
            {
                throw new Exception(
                        "#elif only permitted after #ifdef block, found after "
                        ~ currentDirective[$ - 1].to!string ~ " block");
            }
            string defineName = stripped.split("#elif ")[1];
            if (activeBlock[0 .. $ - 2].all() && activeBlock[$ - 1])
            {
                activeBlock[$ - 1] = false;

            }
            else if (activeBlock[0 .. $ - 2].all() && !activeBlock[$ - 1]
                    && defines.canFind(defineName))
            {
                activeBlock[$ - 1] = true;
            }
            currentDirective ~= PreprocessorDirective.Elseif;
            continue;
        }
        else
        {
            if (stripped.canFind("#else"))
            {
                if (currentDirective[$ - 1] != PreprocessorDirective.Ifdef
                        && currentDirective[$ - 1] != PreprocessorDirective.Elseif)
                {
                    throw new Exception("#else only permitted after #ifdef block or #elif block, found after "
                            ~ currentDirective[$ - 1].to!string ~ " block");
                }
                if (activeBlock[0 .. $ - 2].all() && activeBlock[$ - 1])
                {
                    activeBlock[$ - 1] = false;
                }
                else if (activeBlock[0 .. $ - 2].all() && !activeBlock[$ - 1])
                {
                    activeBlock[$ - 1] = true;
                }
                currentDirective ~= PreprocessorDirective.Else;
                continue;
            }
        }

        if (stripped.canFind("#endif"))
        {
            activeBlock = activeBlock[0 .. $ - 1];
            currentDirective = currentDirective[0 .. $ - 1];
            continue;
        }

        if (activeBlock.all())
        {
            output ~= line;
        }
    }
    return output;
}

void main()
{
}

string[] testcase1 = "#ifdef DEFINED
xyz
#endif".split("\n");

string[] testcase2 = "#ifdef UNDEFINED
abc
#ifdef DEFINED
xyz
#endif
def
#endif
cba".split("\n");

string[] testcase3 = "abc
#ifdef DEFINED
def
#ifdef UNDEFINED
ghi
#endif
jkl
#endif
mno".split("\n");

string[] testcase4 = "#define DEFINED
#ifdef DEFINED
xyz
#endif".split("\n");

string[] testcase5 = "#define DEFINED
#ifdef UNDEFINED
xyz
#else
abc
#endif".split("\n");

string[] testcase6 = "#define DEFINED
#ifdef UNDEFINED
xyz
#elif XYZ
ppp
#else
ccc
#endif".split("\n");

string[] testcase7 = "#define DEFINED
#ifdef UNDEFINED
xyz
#else
ccc
#elif XYZ
ppp
#endif".split("\n");

string[] testcase8 = "// #define DEFINED
// #ifdef DEFINED
xyz
// #endif".split("\n");

string[] testcase9 = `#include "test/file.txt"`.split("\n");

unittest
{
    assert(preprocess(testcase1, ["DEFINED"]) == ["xyz"]);
    assert(preprocess(testcase2, ["DEFINED"]) == ["cba"]);
    assert(preprocess(testcase3, ["DEFINED"]) == ["abc", "def", "jkl", "mno"]);
    assert(preprocess(testcase4, []) == ["xyz"]);
    assert(preprocess(testcase5, []) == ["abc"]);
    assert(preprocess(testcase6, []) == ["ccc"]);
    assertThrown(preprocess(testcase7, []) == ["ccc"]);
    assert(preprocess(testcase8, []) == ["xyz"]);
    assert(preprocess(testcase9, []) == ["xyz", "abc"]);
}
