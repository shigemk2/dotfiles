@echo off

cd %~dp0
if not errorlevel 0 goto err_chdir

if not defined home set home=%USERPROFILE%

setlocal enabledelayedexpansion
for /f %%F in (dotfiles.lst) do (
	set srcfile=%%F
	set dstfile=%%F

	rem ### Convert destination folder name (e.g., src:.vim dst:vimfiles)
	for /f "tokens=1,2*" %%x in (dotfiles.lst.mswin) do (
		if "%%x"=="%%F" (
			set dstfile=%%y
		)
	)
	set src=!CD!\dotfiles\!srcfile:/=\!
	set dst=!home!\!dstfile:/=\!

	if exist "!dst!" (
		echo !dst! exists, skipping ...
	) else (
		for %%D in ("!dst!") do (
			if not exist "%%~dpD" mkdir "%%~dpD"
		)
		if exist "!src!\" (
			rem ### Folder(Junction)
			echo mklink /j "!dst!" "!src!"
			mklink /j "!dst!" "!src!"
		) else (
			rem ### File(Hardlink)
			echo mklink /h "!dst!" "!src!"
			mklink /h "!dst!" "!src!"
		)
		echo.
	)
)
endlocal

goto EOF
rem ====== END ======

:err_chdir
echo error: could not chdir into script directory.

:EOF
