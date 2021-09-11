# 🌐 How to Translate Emulsion

## ✏️ First Things First

* Fork the repository here on github with the Fork button at the top-right
* Clone this repository by opening the terminal in a folder of your choice and typing `git clone https://github.com/<you_username>/emulsion`
* (Optional) Check [Regenerate translations files](https://github.com/lainsce/emulsion/tree/main/po#-regenerate-translations-files) section if files haven't been recently updated.

## 📃 Basics

* You'll need to know your language's code (ex. en = English).
* Add that code to the LINGUAS file, in a new line, after the last line.
* Translate the .pot file using the PO editor of your choice (I recommend POEdit).
* Save it as <language_code>.po in this folder.

## 📝 Not so Basics

* Next, in the folder you've cloned this repo in, open a terminal and type: ```git checkout -b "Translation <language code>```
* Then, type ```git add *```
* Finally, ```git commit -m "Translated your app for <Language Name>" && git push```, follow the instructions in the terminal if need be, then type your github username and password.

And that's it! You've successfully translated Emulsion for your language!

## 🔁 Regenerate translations files
* Initialize the project build by typing `meson _build` (make sure you have [dependencies](https://github.com/lainsce/emulsion#%EF%B8%8F-dependencies) installed!).
* Compile .pot files, type `meson compile -C _build io.github.lainsce.Emulsion-pot`
* (Optional) Compile .po files instead replacing `-pot` with `-update-po` in the previous command.
* Emulsion uses model templates for some parts of its UI that are not detected by gettext when regenerating the pot file, so you have to add them manually. Check the dropdown!

<details>
<summary>Missing lines</summary>

###

⚠️ Note that line numbers will be different depending on when you regenerate the pot file, check `data/ui/window.ui` and change them where each line is located. Remember that the pot file is sorted by file and line number when pasting these lines.

<pre>
#: data/ui/window.ui:210<br>msgid "Copy Palette to Clipboard"<br>msgstr ""<br>
#: data/ui/window.ui:214<br>msgid "Copy Palette Image to Clipboard"<br>msgstr ""<br>
#: data/ui/window.ui:220<br>msgid "Remove Palette"<br>msgstr ""
</pre>

...

<pre>
#: data/ui/window.ui:349<br>msgid "Copy Hexcode to Clipboard"<br>msgstr ""<br>
#: data/ui/window.ui:353<br>msgid "Copy RGB to Clipboard"<br>msgstr ""<br>
#: data/ui/window.ui:359<br>msgid "Remove Color from Palette"<br>msgstr ""
</pre>
</details>

Note: install `appstream` package in order to generate release strings.
