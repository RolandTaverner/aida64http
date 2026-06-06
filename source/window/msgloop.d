module window.msgloop;

import windows.win32.ui.windowsandmessaging;
import windows.win32.foundation : LRESULT, HWND, WPARAM, LPARAM, PWSTR, HINSTANCE, FALSE;

public shared class MessageLoop
{
    public this(HINSTANCE hInst)
    {
        this.hInstance = cast(shared)hInst;
    }
    
    public void run()
    {
        auto className = PWSTR(cast(wchar*)CLASS_NAME.ptr);

        WNDCLASSW wc = WNDCLASSW(lpszClassName: className);
        wc.lpfnWndProc = &wndProc;
        wc.hInstance = cast(HINSTANCE)hInstance;
        wc.hCursor = LoadCursorW(HINSTANCE(null), IDC_ARROW);
        RegisterClassW(&wc);

        auto windowName = PWSTR(cast(wchar*)WINDOW_NAME.ptr);

        hWnd = cast(shared)CreateWindowExW(
            0, className, windowName, 
            WS_OVERLAPPEDWINDOW, 
            CW_USEDEFAULT, CW_USEDEFAULT, 640, 480, 
            HWND(null), HMENU(null), cast(HINSTANCE)hInstance, null
        );

        if (hWnd.Value == null){
            return;
        }

        //ShowWindow(hwnd, nCmdShow);

        // 5. The Core Message Loop
        MSG msg;
        while (GetMessageW(&msg, HWND(null), 0, 0) != FALSE)
        {
            TranslateMessage(&msg); // Translates keystrokes into characters
            DispatchMessageW(&msg);  // Sends the message to the WindowProc
        }
    }

    public bool stop()
    {
        return PostMessageW(cast(HWND)hWnd, WM_DESTROY, WPARAM(), LPARAM()) != FALSE;
    }

    const(wchar[]) CLASS_NAME = cast(shared)"aida64httpWindowClass"w.dup;
    const(wchar[]) WINDOW_NAME = cast(shared)"aida64http"w.dup;
    private HINSTANCE hInstance;
    private HWND hWnd;
}

public void worker(void delegate() shared dg)
{
    dg();
}

extern (Windows) private LRESULT wndProc(HWND hWnd, uint msg, WPARAM wParam, LPARAM lParam) @nogc nothrow
{
    switch (msg) 
    {
        case WM_DESTROY:
            PostQuitMessage(0); // Signals the message loop to terminate
            return LRESULT(0);
        default:
            return DefWindowProcW(hWnd, msg, wParam, lParam); // Default processing
    }
}
