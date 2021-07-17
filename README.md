# CadencePCBLayoutReview
GUI that provides functionality making [Cadence PCB Layout](https://www.orcad.com/) much easier to read and review.  

* *It has NO effect on the fabrication and manufacturing layers (eg ASSEMBLY, SILKSCREEN)*
* orients, centers, and automatically sizes the REFDES's and pin designations on the TOP DISPLAY layer
* orients, changes to forward direction, centers, and automatically sizes the REFDES's and pin designations on the BOTTOM DISPLAY layer
* gives easy control of the colors used for the display layer via a set of three +/- buttons for Hue, Saturation, and Lightness ([HSL](https://en.wikipedia.org/wiki/HSL_and_HSV)).

The script is written in [Cadence SKILL](https://en.wikipedia.org/wiki/Cadence_SKILL), which is a variant of [Lisp](https://en.wikipedia.org/wiki/Lisp_(programming_language)).

## INSTALLTION

1. copy `PCBReview.il` to the `C:\Cadence\setup\skill` folder. This is the Skill script.
2. merge `allegro.ilinit` with the file of the same name in `is C:\Cadence\VERSION\pcbenv` folder, or copy if none exists.  This file loads all the scripts in the `C:\Cadence\setup\skill` folder initialization of OrCAD Layout.  (`allegro.ilinit` is the initialization fiel for OrCAD Layout.)


## POPUP WINDOW
![Screen shot of popup window](screenshot.png)

## EXAMPLE RESULT

![example1 of result](example1.png)
![example2 of result](example2.png)
![example3 of result](example3.png)
![example4 of result](example4.png)


