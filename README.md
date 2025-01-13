# firefox-webdriver-patch

Binary patch Firefox to always return `false` for the `navigator.webdriver` property.

## Table of Contents

- [Quickstart](#quickstart)
- [Testing if it Worked](#testing-if-it-worked)
- [Prerequisites](#prerequisites)
    - [Debian](#debian)
        - [Setting up Debugging Symbols](#setting-up-debugging-symbols)
        - [Installing Dependencies](#installing-dependencies)
- [Other Ways of Achieving the Same Goal](#other-ways-of-achieving-the-same-goal)
    - [Using a Violentmonkey userscript](#using-a-violentmonkey-userscript)
    - [Modifying Firefox](#modifying-firefox)
    - [Manual Patching](#manual-patching)

## Quickstart

First set up the [debugging symbols](#setting-up-debugging-symbols) for Firefox and install the [dependencies](#installing-dependencies).

Enter Gforth interpreter as root:

```console
$ sudo gforth
```

Type the following commands into Gforth's interpreter.

```forth
include patch.4th
s" /usr/lib/firefox-esr/libxul.so" filepath!
find-offset
apply-patch
```

Assuming all went well, your Firefox is now patched!

## Testing if it Worked

Assuming you didn't get any errors while patching, you should test that
the patch was successful.

1. close Firefox
2. open Firefox from the command line with marionette enabled `firefox --marionette`, this normally sets `navigator.webdriver` to `true`
3. open the inspector
4. type `navigator.webdriver` into the console
5. verify that it is `false`

## Prerequisites

This patcher was developed and tested on Debian 12 but it may also work on other distributions.

For this patcher to work, you need to have gdb, gforth, Firefox and the
debugging symbols for Firefox installed.

### Debian

#### Setting up Debugging Symbols

See [the debian wiki](https://wiki.debian.org/HowToGetABacktrace#Installing_the_debugging_symbols).

#### Installing Dependencies

```console
$ sudo apt install gdb gforth firefox-esr-dbgsym
```

## Other Ways of Achieving the Same Goal

### Using a Violentmonkey userscript

You can use [Violentmonkey](https://addons.mozilla.org/en-US/firefox/addon/violentmonkey/) with [my script](https://github.com/xn435/not-webdriver) to proxy `navigator.webdriver` to return `false`.

This will work for many websites, but more sophisticated bot detection methods will be able to tell that the `navigator.webdriver` property is being proxied.

### Modifying Firefox

The only reason I wrote this patcher is because I didn't want to keep a separate copy of Firefox or have to compile Firefox from source just for this really tiny change.

However, if you're willing to compile Firefox from source, then this is a trivial modification.

In Firefox's source directory open `./dom/base/Navigator.cpp` and find the `Navigator::Webdriver` method.

It should look like this:

```cpp
bool Navigator::Webdriver() {
#ifdef ENABLE_WEBDRIVER
  nsCOMPtr<nsIMarionette> marionette = do_GetService(NS_MARIONETTE_CONTRACTID);
  if (marionette) {
    bool marionetteRunning = false;
    marionette->GetRunning(&marionetteRunning);
    if (marionetteRunning) {
      return true;
    }
  }

  nsCOMPtr<nsIRemoteAgent> agent = do_GetService(NS_REMOTEAGENT_CONTRACTID);
  if (agent) {
    bool remoteAgentRunning = false;
    agent->GetRunning(&remoteAgentRunning);
    if (remoteAgentRunning) {
      return true;
    }
  }
#endif

  return false;
}
```

Modify it to return false:

```cpp
bool Navigator::Webdriver() {
  return false;
}
```

Now compile and install Firefox. `navigator.webdriver` will always be `false`.

## Manual Patching

Here I'll describe how the patching works.

```console
$ gdb /usr/lib/firefox-esr/libxul.so
```

after loading, gdb should tell us that debugging symbols were loaded for `libxul.so`:

```console
Reading symbols from /usr/lib/firefox-esr/libxul.so...
Reading symbols from /usr/lib/debug/.build-id/16/249d01b5f11eaf47fceedf77b9a846bdcc3c6f.debug...
```

If gdb says it can't find debugging symbols for libxul.so then see [Setting up Debugging Symbols](#setting-up-debugging-symbols).

```console
(gdb) break Navigator::Webdriver
Breakpoint 1 at 0x1a04810: file ./dom/base/Navigator.cpp, line 2290.
```

gdb found the offset for the method at `0x1a04810`, which is `27281424` in decimal. This offset will likely be different for you. Now we just need to write the bytes for the instructions starting at that offset into libxul.so.

In x86_64 assembly on GNU/Linux the instructions to return false from a function are:

```x86_64
xor rax, rax
ret
```

The patcher uses Gforth's built-in x86_64 assembler to generate the bytes for the instructions. You can just use an online assembler like [here](https://defuse.ca/online-x86-assembler.htm) and copy the resulting bytes.

You should get `48 31 C0 C3` for the above mentioned assembly instructions. Replace `METHOD_OFFSET` with the offset you found.

```console
$ METHOD_OFFSET=27281424
$ echo -n -e '\x48\x31\xC0\xC3' > patch.bin
$ sudo dd if=patch.bin of=/usr/lib/firefox-esr/libxul.so seek=$METHOD_OFFSET bs=1 conv=notrunc
```
