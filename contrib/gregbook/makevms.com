$!------------------------------------------------------------------------------
$! make Contrib programs of libpng under OpenVMS
$!
$!
$! Look for the compiler used
$!
$ zlibsrc = "[---.zlib]"
$ ccopt="/include=(''zlibsrc',[--])"
$ if f$getsyi("HW_MODEL").ge.1024
$ then
$  ccopt = "/prefix=all"+ccopt
$  comp  = "__decc__=1"
$  if f$trnlnm("SYS").eqs."" then define sys sys$library:
$ else
$  if f$search("SYS$SYSTEM:DECC$COMPILER.EXE").eqs.""
$   then
$    if f$trnlnm("SYS").eqs."" then define sys sys$library:
$    if f$search("SYS$SYSTEM:VAXC.EXE").eqs.""
$     then
$      comp  = "__gcc__=1"
$      CC :== GCC
$     else
$      comp = "__vaxc__=1"
$     endif
$   else
$    if f$trnlnm("SYS").eqs."" then define sys decc$library_include:
$    ccopt = "/decc/prefix=all"+ccopt
$    comp  = "__decc__=1"
$  endif
$ endif
$ open/write lopt lib.opt
$ write lopt "[--]libpng.olb/lib"
$ write lopt "''zlibsrc'libz.olb/lib"
$ close lopt
$ open/write xopt x11.opt
$ write xopt "sys$library:decw$xlibshr.exe/share"
$ close xopt
$ write sys$output "Compiling PNG contrib programs ..."
$   CALL MAKE readpng.OBJ "cc ''CCOPT' readpng" -
	readpng.c readpng.h
$   CALL MAKE readpng2.OBJ "cc ''CCOPT' readpng2" -
	readpng2.c readpng2.h
$   CALL MAKE writepng.OBJ "cc ''CCOPT' writepng" -
	writepng.c writepng.h
$   write sys$output "Building rpng-x..."
$   CALL MAKE rpng-x.OBJ "cc ''CCOPT' rpng-x" -
	rpng-x.c readpng.h
$   call make rpng-x.exe -
	"LINK rpng-x,readpng,lib.opt/opt,x11.opt/opt" -
	rpng-x.obj readpng.obj
$   write sys$output "Building rpng2-x..."
$   CALL MAKE rpng2-x.OBJ "cc ''CCOPT' rpng2-x" -
	rpng2-x.c readpng2.h
$   call make rpng2-x.exe -
	"LINK rpng2-x,readpng2,lib.opt/opt,x11.opt/opt" -
	rpng2-x.obj readpng2.obj
$   write sys$output "Building wpng..."
$   CALL MAKE wpng.OBJ "cc ''CCOPT' wpng" -
	wpng.c writepng.h
$   call make wpng.exe -
	"LINK wpng,writepng,lib.opt/opt" -
	wpng.obj writepng.obj
$ exit
$!
$!
$MAKE: SUBROUTINE   !SUBROUTINE TO CHECK DEPENDENCIES
$ V = 'F$Verify(0)
$! P1 = What we are trying to make
$! P2 = Command to make it
$! P3 - P8  What it depends on
$
$ If F$Search(P1) .Eqs. "" Then Goto Makeit
$ Time = F$CvTime(F$File(P1,"RDT"))
$arg=3
$Loop:
$       Argument = P'arg
$       If Argument .Eqs. "" Then Goto Exit
$       El=0
$Loop2:
$       File = F$Element(El," ",Argument)
$       If File .Eqs. " " Then Goto Endl
$       AFile = ""
$Loop3:
$       OFile = AFile
$       AFile = F$Search(File)
$       If AFile .Eqs. "" .Or. AFile .Eqs. OFile Then Goto NextEl
$       If F$CvTime(F$File(AFile,"RDT")) .Ges. Time Then Goto Makeit
$       Goto Loop3
$NextEL:
$       El = El + 1
$       Goto Loop2
$EndL:
$ arg=arg+1
$ If arg .Le. 8 Then Goto Loop
$ Goto Exit
$
$Makeit:
$ VV=F$VERIFY(0)
$ write sys$output P2
$ 'P2
$ VV='F$Verify(VV)
$Exit:
$ If V Then Set Verify
$ENDSUBROUTINE