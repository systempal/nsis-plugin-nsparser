/*
	nsParser NSIS plugin
	Extract patterns from text/HTML files
*/

#include <windows.h>
#include "pluginapi.h"
#include "nsParser.h"

HANDLE g_hInstance;

static UINT_PTR PluginCallback(enum NSPIM msg)
{
	return 0;
}

BOOL WINAPI DllMain(HANDLE hInst, ULONG ul_reason_for_call, LPVOID lpReserved)
{
	g_hInstance = hInst;
	return TRUE;
}

// Find pattern in file and extract value between quotes
static BOOL ExtractVersion(PTCHAR pszFilename, PCHAR pszPattern, PTCHAR pszVersion, DWORD dwVersionSize)
{
	HANDLE hFile;
	DWORD dwBytesRead;
	CHAR szBuffer[8192];
	CHAR szSearchBuffer[16384] = {0};
	DWORD dwSearchBufferLen = 0;
	DWORD dwPatternLen = lstrlenA(pszPattern);
	BOOL bFound = FALSE;

	// Open file
	hFile = CreateFile(pszFilename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
	if (hFile == INVALID_HANDLE_VALUE)
		return FALSE;

	// Read file in chunks
	while (ReadFile(hFile, szBuffer, sizeof(szBuffer), &dwBytesRead, NULL) && dwBytesRead > 0)
	{
		// Append to search buffer
		if (dwSearchBufferLen + dwBytesRead < sizeof(szSearchBuffer))
		{
			CopyMemory(szSearchBuffer + dwSearchBufferLen, szBuffer, dwBytesRead);
			dwSearchBufferLen += dwBytesRead;
		}
		else
		{
			// Buffer full, keep last 2KB and continue
			MoveMemory(szSearchBuffer, szSearchBuffer + dwSearchBufferLen - 2048, 2048);
			CopyMemory(szSearchBuffer + 2048, szBuffer, dwBytesRead);
			dwSearchBufferLen = 2048 + dwBytesRead;
		}
		szSearchBuffer[dwSearchBufferLen] = '\0';

		// Search for pattern
		PCHAR pszFound = strstr(szSearchBuffer, pszPattern);
		if (pszFound)
		{
			// Found! Extract value between quotes
			// Format: "RDM7zX64.Version":"2025.3.21.0"
			PCHAR pszColon = strchr(pszFound + dwPatternLen, ':');
			if (pszColon)
			{
				PCHAR pszOpenQuote = strchr(pszColon, '"');
				if (pszOpenQuote)
				{
					PCHAR pszCloseQuote = strchr(pszOpenQuote + 1, '"');
					if (pszCloseQuote)
					{
						// Extract version
						DWORD dwLen = (DWORD)(pszCloseQuote - pszOpenQuote - 1);
						if (dwLen < dwVersionSize)
						{
							// Convert to TCHAR
#ifdef UNICODE
							MultiByteToWideChar(CP_ACP, 0, pszOpenQuote + 1, dwLen, pszVersion, dwVersionSize);
							pszVersion[dwLen] = 0;
#else
							CopyMemory(pszVersion, pszOpenQuote + 1, dwLen);
							pszVersion[dwLen] = 0;
#endif
							bFound = TRUE;
							break;
						}
					}
				}
			}
		}
	}

	CloseHandle(hFile);
	return bFound;
}

// NSIS Plugin function: Extract
// Usage: nsParser::Extract "filepath" "pattern"
// Returns: "OK" or "ERROR", then extracted value
NSISFUNC(Extract)
{
	DLL_INIT();
	{
		TCHAR szFilepath[1024];
		TCHAR szPattern[256];
		CHAR szPatternA[256];
		TCHAR szVersion[256] = {0};

		// Pop filepath
		if (popstring(szFilepath) != 0)
		{
			pushstring(TEXT(""));
			pushstring(TEXT("ERROR"));
			return;
		}

		// Pop pattern
		if (popstring(szPattern) != 0)
		{
			pushstring(TEXT(""));
			pushstring(TEXT("ERROR"));
			return;
		}

		// Convert pattern to ANSI for file searching
#ifdef UNICODE
		WideCharToMultiByte(CP_ACP, 0, szPattern, -1, szPatternA, sizeof(szPatternA), NULL, NULL);
#else
		lstrcpyA(szPatternA, szPattern);
#endif

		// Extract version
		if (ExtractVersion(szFilepath, szPatternA, szVersion, sizeof(szVersion) / sizeof(TCHAR)))
		{
			pushstring(szVersion);
			pushstring(TEXT("OK"));
		}
		else
		{
			pushstring(TEXT(""));
			pushstring(TEXT("ERROR"));
		}
	}
}
