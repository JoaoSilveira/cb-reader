import Elm, { InitArgs } from './elm';

const Images: Record<string, string> = {
    ".apng": "image/apng",
    ".avif": "image/avif",
    ".gif": "image/gif",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".jfif": "image/jpeg",
    ".pjpeg": "image/jpeg",
    ".pjp": "image/jpeg",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".ico": "image/x-icon",
    ".cur": "image/x-icon",
    ".tif": "image/tiff",
    ".tiff": "image/tiff",
};

async function processFlags(): Promise<InitArgs['flags']> {
    const promises = await Promise.allSettled(
        NL_ARGS.slice(1)
            .map(arg => Neutralino.filesystem.getStats(arg))
    );

    for (let i = 0; i < promises.length; i++) {
        const promise = promises[i];

        if (promise.status !== 'fulfilled' || promise.value.isDirectory) {
            continue;
        }

        return {
            screen: 'read',
            payload: NL_ARGS[i + 1],
        };
    }

    return { screen: 'home', payload: undefined };
}

processFlags().then(flags => {
    const app = Elm.Main.init({
        node: document.getElementById('main')!,
        flags,
    });
    (window as any).app = app;

    app.ports.notifyPageChangePort.subscribe((obj) => {
        document.getElementById('page-container')?.scrollTo(0, 0);
        console.log('Changed page to', obj.currentPage);
    });

    app.ports.requestHistoryPort.subscribe(async () => {
        await new Promise((resolve) => setTimeout(resolve, 1000));

        console.warn("TODO: request history");

        app.ports.onHistoryResultPort.send({
            success: true,
            payload: []
        });
    });

    app.ports.requestPagesPort.subscribe(async (pagePayload) => {
        let pageIndex = 0;

        try {
            const reader = await Neutralino.filesystem.readBinaryFile(pagePayload.path)
                .then(bytes => new Uint8Array(bytes))
                .then(bytes => JSZip.loadAsync(bytes));

            for (; pageIndex < pagePayload.pages.length; pageIndex++) {
                const page = pagePayload.pages[pageIndex];
                const ext = page.substring(page.lastIndexOf('.'));
                try {
                    const entry = reader.file(page);
                    if (!entry) {
                        app.ports.onPageResultPort.send({
                            success: false,
                            error: {
                                code: 'PAGE_NOT_FOUND',
                                message: `Page "${page}" was not found the the archive. Archive path: ${pagePayload.path}`,
                                page,
                            }
                        });
                        continue;
                    }

                    app.ports.onPageResultPort.send({
                        success: true,
                        payload: {
                            page: page,
                            data: `data:image/${Images[ext]};base64,${await entry.async("base64")}`,
                        }
                    });
                } catch (e) {
                    app.ports.onPageResultPort.send({
                        success: false,
                        error: {
                            code: typeof e.code === 'string' ? e.code : e.name,
                            message: e.message,
                            page,
                        }
                    });
                }
            }
        } catch (e) {
            for (; pageIndex < pagePayload.pages.length; pageIndex++) {
                app.ports.onPageResultPort.send({
                    success: false,
                    error: {
                        code: typeof e.code === 'string' ? e.code : e.name,
                        message: e.message,
                        page: pagePayload.pages[pageIndex],
                    }
                });
            }
        }
    });

    app.ports.requestMetadataPort.subscribe(async (path) => {
        try {
            const reader = await Neutralino.filesystem.readBinaryFile(path)
                .then(bytes => new Uint8Array(bytes))
                .then(bytes => JSZip.loadAsync(bytes));

            const pages: string[] = [];
            reader.forEach((filename: string) => {
                const dot = filename.lastIndexOf('.');
                if (dot >= 0 && filename.substring(dot) in Images) {
                    pages.push(filename)
                }
            });

            app.ports.onMetadataResultPort.send({
                success: true,
                payload: {
                    pages,
                    path,
                }
            })
        } catch (e) {
            app.ports.onMetadataResultPort.send({
                success: false,
                error: {
                    code: typeof e.code === 'string' ? e.code : e.name,
                    message: e.message,
                }
            });
        }
    });

    app.ports.requestFileSelectModalPort.subscribe(async () => {
        const files = await Neutralino.os.showOpenDialog('Select Comic Book File', {
            filters: [
                { name: "Comic Book (*.cbz)", extensions: ['cbz'] },
                { name: "Zip Archive or Comic Book (*.cbz|*.zip)", extensions: ['cbz', 'zip'] },
                { name: "Zip Archive (*.zip)", extensions: ['zip'] },
                { name: "All Files (*.*)", extensions: ['*'] },
            ],
            multiSelections: false,
        });

        if (files.length > 0) {
            const path = files[0];
            app.ports.onFileSelectedPort.send(path)
        }
    });
});

Neutralino.init();
Neutralino.events.on("windowClose", () => void (Neutralino.app.exit()));