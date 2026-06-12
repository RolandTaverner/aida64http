module window.msgloop;

import std.logger;
import std.utf : toUTF16z;

import windows.win32.ui.windowsandmessaging;
import windows.win32.foundation : LRESULT, HWND, WPARAM, LPARAM, PWSTR, HINSTANCE, FALSE, TRUE, GetLastError;
import windows.win32.ui.shell : NIM_ADD, NIM_DELETE, NIF_MESSAGE, NIF_ICON, NIF_TIP, NIIF_NONE, NOTIFYICONDATAW, Shell_NotifyIconW;

import vibe.core.core : exitEventLoop;
import resource;

public shared class MessageLoop
{
    public this(HINSTANCE hInst)
    {
        this.hInstance = cast(shared) hInst;
    }

    public void run()
    {
        if (!createWindow())
        {
            errorf("Can't create window: error %d", GetLastError());
        }
        else
        {
            info("Window created");
        }

        if (!createTrayIcon())
        {
            errorf("Can't create tray icon: error %d", GetLastError());
        }
        else
        {
            info("Tray icon created");
        }

        info("Starting message loop");
        // Run message loop
        MSG msg;
        while (GetMessageW(&msg, HWND(null), 0, 0) != FALSE)
        {
            TranslateMessage(&msg); // Translates keystrokes into characters
            DispatchMessageW(&msg); // Sends the message to the WindowProc
        }
        info("Message loop finished");

        hideTrayIcon();
        UnregisterClassW(PWSTR(cast(wchar*) CLASS_NAME.ptr), cast(HINSTANCE) hInstance);

        // Stop vibe.d event loop
        exitEventLoop(true);
    }

    public bool stop()
    {
        return PostMessageW(cast(HWND) hWnd, WM_CLOSE, WPARAM(), LPARAM()) != FALSE;
    }

    private bool createWindow()
    {
        auto className = PWSTR(cast(wchar*) CLASS_NAME.ptr);

        HICON icon = LoadIconW(cast(HINSTANCE) hInstance, makeIntResource(IDI_AIDA64HTTP_ICON));
        assert(icon.Value != null, "LoadIconW for IDI_AIDA64HTTP_ICON returned null");
        if (icon.Value == null)
        {
            error("LoadIconW error");
            return false;
        }

        HICON iconSmall = LoadIconW(cast(HINSTANCE) hInstance, makeIntResource(IDI_AIDA64HTTP_ICON_SMALL));
        assert(icon.Value != null, "LoadIconW for IDI_AIDA64HTTP_ICON_SMALL returned null");
        if (iconSmall.Value == null)
        {
            error("LoadIconW error");
            return false;
        }

        hMenu = cast(shared) LoadMenuW(cast(HINSTANCE) hInstance, makeIntResource(IDC_AIDA64HTTP_MENU));
        assert(hMenu.Value != null, "LoadMenuW returned null");
        if (hMenu.Value == null)
        {
            error("LoadMenuW error");
            return false;
        }

        hPopupMenu = cast(shared) GetSubMenu(cast(HMENU) hMenu, 0);
        assert(hPopupMenu.Value != null, "GetSubMenu returned null");
        if (hPopupMenu.Value == null)
        {
            error("GetSubMenu error");
            return false;
        }

        WNDCLASSEXW wc = WNDCLASSEXW(cbSize : WNDCLASSEXW.sizeof, lpszClassName : className);
        wc.lpfnWndProc = &wndProc;
        wc.hInstance = cast(HINSTANCE) hInstance;
        wc.hCursor = LoadCursorW(HINSTANCE(null), IDC_ARROW);
        wc.hIcon = icon;
        wc.hIconSm = iconSmall;
        RegisterClassExW(&wc);

        auto windowName = PWSTR(cast(wchar*) WINDOW_NAME.ptr);

        hWnd = cast(shared) CreateWindowExW(
            0, className, windowName, WS_OVERLAPPEDWINDOW,
            CW_USEDEFAULT, CW_USEDEFAULT, 640, 480,
            HWND(null), HMENU(null), cast(HINSTANCE) hInstance, null
        );

        SetWindowLongPtrW(cast(HWND) hWnd, GWLP_USERDATA, cast(ptrdiff_t) cast(void*) this);
        return hWnd.Value != null;
    }

    private bool createTrayIcon()
    {
        NOTIFYICONDATAW notifyIconData = NOTIFYICONDATAW();

        HICON icon = LoadIconW(cast(HINSTANCE) hInstance, makeIntResource(IDI_AIDA64HTTP_ICON_SMALL));
        assert(icon.Value != null, "LoadIconW for IDI_AIDA64HTTP_ICON_SMALL returned null");
        if (icon.Value == null)
        {
            error("LoadIconW error");
            return false;
        }

        notifyIconData.cbSize = NOTIFYICONDATAW.sizeof;
        notifyIconData.hWnd = cast(HWND) hWnd;
        notifyIconData.uID = IDI_AIDA64HTTP_ICON_SMALL; // We have only 1 icon so this doesnt matter
        notifyIconData.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
        notifyIconData.uCallbackMessage = WM_TRAYICON;
        notifyIconData.hIcon = icon;

        for (int i = 0; i < TrayTip.length && i < notifyIconData.szTip.length - 1;
            ++i)
        {
            notifyIconData.szTip[i] = TrayTip[i];
        }

        notifyIconData.dwState = 0;
        notifyIconData.dwStateMask = 0;
        notifyIconData.szInfo[0] = 0;
        notifyIconData.szInfoTitle[0] = 0;
        notifyIconData.dwInfoFlags = NIIF_NONE;
        notifyIconData.hBalloonIcon = HICON(null);

        return Shell_NotifyIconW(NIM_ADD, &notifyIconData) != FALSE;
    }

    private bool hideTrayIcon()
    {
        NOTIFYICONDATAW notifyIconData = NOTIFYICONDATAW();
        notifyIconData.cbSize = NOTIFYICONDATAW.sizeof;
        notifyIconData.hWnd = cast(HWND) hWnd;
        notifyIconData.uID = IDI_AIDA64HTTP_ICON_SMALL;

        return Shell_NotifyIconW(NIM_DELETE, cast(NOTIFYICONDATAW*)&notifyIconData) != FALSE;
    }

    private void showTrayMenu() @nogc nothrow
    {
        if (SetForegroundWindow(cast(HWND) hWnd) == FALSE)
        {
            //error("SetForegroundWindow error" , GetLastError());
            return;
        }
        POINT pt;
        if (GetCursorPos(&pt) == FALSE)
        {
            //error("GetCursorPos error" , GetLastError());
            return;   
        }

        TrackPopupMenu(cast(HMENU) hPopupMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, pt.x, pt.y, 0, cast(HWND)hWnd, null);

        // Required workaround to clear the message loop context
        PostMessageW(cast(HWND)hWnd, WM_NULL, WPARAM(0), LPARAM(0));
    }

    public HINSTANCE getInstance() const @nogc nothrow
    {
        return cast(HINSTANCE) hInstance;
    }

    private const(wchar[]) CLASS_NAME = cast(shared) "aida64httpWindowClass"w.dup;
    private const(wchar[]) WINDOW_NAME = cast(shared) "aida64http"w.dup;
    private HINSTANCE hInstance;
    private HWND hWnd;
    private HMENU hMenu;
    private HMENU hPopupMenu;
}

private enum uint WM_TRAYICON = (WM_USER + 1);
private enum wstring TrayTip = "AIDA64HTTP";

extern (Windows) private LRESULT wndProc(HWND hWnd, uint msg, WPARAM wParam, LPARAM lParam) @nogc nothrow
{
    switch (msg)
    {
    case WM_COMMAND:
        ushort wmId = cast(ushort) wParam.Value;
        // Parse the menu selections:
        switch (wmId)
        {
        case IDM_ABOUT:
            auto userData = cast (void*) GetWindowLongPtrW(hWnd, GWLP_USERDATA);
            assert(userData != null, "GetWindowLongPtrW returned null");
            if (userData != null)
            {
                auto thisPtr = cast(shared MessageLoop) userData;
                DialogBoxParamW(thisPtr.getInstance(), makeIntResource(IDD_ABOUTBOX), hWnd, &aboutWndProc, LPARAM());
            }
            break;
        case IDM_EXIT:
            DestroyWindow(hWnd);
            break;
        default:
            return DefWindowProcW(hWnd, msg, wParam, lParam);
        }
        break;
    case WM_TRAYICON:
        ushort lParamLoWord = cast(ushort) lParam.Value;
        if (lParamLoWord == WM_RBUTTONUP || lParamLoWord == WM_CONTEXTMENU)
        {
            auto userData = cast (void*) GetWindowLongPtrW(hWnd, GWLP_USERDATA);
            assert(userData != null, "GetWindowLongPtrW returned null");
            if (userData != null)
            {
                auto thisPtr = cast(shared MessageLoop) userData;
                thisPtr.showTrayMenu();
            }
        }
        break;
    case WM_DESTROY:
        PostQuitMessage(0); // Signals the message loop to terminate
        break;
    default:
        return DefWindowProcW(hWnd, msg, wParam, lParam); // Default processing
    }

    return LRESULT(0);
}

// Message handler for about box.
extern (Windows) private ptrdiff_t aboutWndProc(HWND hDlg, uint msg, WPARAM wParam, LPARAM lParam) @nogc nothrow
{
    switch (msg)
    {
    case WM_INITDIALOG:
        return TRUE.Value;
    case WM_COMMAND:
        ushort wmId = cast(ushort) wParam.Value;
        if (wmId == IDOK || wmId == IDCANCEL)
        {
            EndDialog(hDlg, wmId);
            return TRUE.Value;
        }
        break;
    default:
        // do nothing
    }

    return FALSE.Value;
}

PWSTR makeIntResource(uint resourceId) @nogc nothrow
{
    return PWSTR(cast(wchar*)(cast(ushort) resourceId));
}