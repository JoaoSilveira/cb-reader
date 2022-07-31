import { Data64URIWriter, Uint8ArrayReader, ZipReader } from '@zip.js/zip.js';
import Elm, { InitArgs, PageEntry } from './elm';

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
            payload: {
                path: NL_ARGS[i + 1],
                name: "No name",
                pages: await processComicBookFile(NL_ARGS[i + 1]),
            }
        };
    }

    return { screen: 'home', payload: [] };
}

async function processComicBookFile(path: string): Promise<PageEntry[]> {
    let reader = null;

    try {
        const content = await Neutralino.filesystem.readBinaryFile(path)
            .then(c => new Uint8Array(c))
            .then(a => new Uint8ArrayReader(a));
        reader = new ZipReader(content);

        const entries = await reader.getEntries();
        return await Promise.all(
            entries
                .filter(entry => !entry.directory)
                .map(entry => entry.getData!(new Data64URIWriter("image/jpg")))
        );
    } finally {
        await reader?.close();
    }
}

processFlags().then(flags => {
    const app = Elm.Main.init({
        node: document.getElementById('main')!,
        flags,
    });

    app.ports.notifyPageChangePort.subscribe((obj) => {
        document.getElementById('page-container')?.scrollTo(0, 0);
        console.log('Changed page to', obj.currentPage);
    });

    app.ports.requestOpenFilePort.subscribe(async (path) => {
        const pages = await processComicBookFile(path);

        app.ports.onOpenFilePort.send({
            name: "The thingy",
            path,
            pages,
        });
    });

    app.ports.openFileSelectModalPort.subscribe(async () => {
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
            const name = path.substring(Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\')));

            app.ports.onOpenFilePort.send({
                path,
                name,
                pages: await processComicBookFile(path)
            })
        }
    });
});

Neutralino.init();
Neutralino.events.on("windowClose", () => void (Neutralino.app.exit()));