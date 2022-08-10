interface HistoryEntry {
    /** The path to the archive */
    path: string;
    /** The path of the last page read */
    page: string;
    /** The datetime of the entry */
    date: number;
    /** The thumbnail of the comic book (first page if no thumbnail in the archive) */
    thumbnail: string;
    /** The title of the comic book */
    title?: string;
    /** The author of the comic book */
    author?: string;
}

type TextOperation = 'starts-with' | 'contains' | 'ends-with' | 'equals' | 'regex';
interface TextFilter {
    value: string | RegExp;
    operation: TextOperation;
    sensitive?: boolean;
}

interface IHistoryListOptions {
    order?: 'newer' | 'older';
    period?: {
        from?: Date | number;
        to?: Date | number;
    },
    title?: TextFilter,
    path?: TextFilter,
    author?: TextFilter,
}

interface IHistoryStorage {
    add(entry: HistoryEntry): Promise<void>;
    update(entry: HistoryEntry): Promise<void>;
    update(path: string, updater: (entry: HistoryEntry) => HistoryEntry): Promise<void>;
    update(entryOrPath: string | HistoryEntry, updater?: (entry: HistoryEntry) => HistoryEntry): Promise<void>;
    remove(entry: HistoryEntry): Promise<void>;
    list(options?: IHistoryListOptions): Promise<HistoryEntry[]>;
}

function textOperationToPredicate(options: TextFilter): (value: string) => boolean {
    if (options.operation === 'regex') {
        const regex = new RegExp(options.value, options.sensitive ? '' : 'i');

        return (v: string) => regex.test(v);
    }
    if (typeof options.value !== 'string') {
        // TODO - Throw an actual error
        throw new Error('');
    }

    const value = options.sensitive ? options.value : options.value.toLocaleLowerCase();
    let predicate: (v: string) => boolean;
    switch (options.operation) {
        case "contains":
            predicate = (v: string) => v.includes(value);
            break;
        case "starts-with":
            predicate = (v: string) => v.startsWith(value);
            break;
        case "ends-with":
            predicate = (v: string) => v.endsWith(value);
            break;
        case "equals":
            predicate = (v: string) => v === value;
            break;
        default:
            // TODO - Throw an actual error
            throw new Error('');
    }

    return options.sensitive ? predicate : (v: string) => predicate(v.toLocaleLowerCase());
}

function optionsToPredicate(options: IHistoryListOptions): (entry: HistoryEntry) => boolean {
    const predicates: ((entry: HistoryEntry) => boolean)[] = [];

    if (options.period?.from != null) {
        let from = options.period!.from;
        from = typeof from === 'number' ? from : from.getTime();

        predicates.push(entry => entry.date >= from);
    }

    if (options.period?.to != null) {
        let to = options.period!.to;
        to = typeof to === 'number' ? to : to.getTime();

        predicates.push(entry => entry.date <= to);
    }

    if (options.author != null) {
        const pred = textOperationToPredicate(options.author);
        predicates.push(entry => pred(entry.author ?? ''));
    }

    if (options.title != null) {
        const pred = textOperationToPredicate(options.title);
        predicates.push(entry => pred(entry.title ?? ''));
    }

    if (options.path != null) {
        const pred = textOperationToPredicate(options.path);
        predicates.push(entry => pred(entry.path));
    }

    return entry => predicates.every(p => p(entry));
}

class NeutralinoStorage implements IHistoryStorage {
    private historyByPath: Map<string, HistoryEntry>;

    protected constructor(entries: HistoryEntry[]) {
        this.historyByPath = entries.reduce((map, entry) => map.set(entry.path, entry), new Map<string, HistoryEntry>());
    }

    private async updateHistory(): Promise<void> {
        await Neutralino.storage.setData('history', JSON.stringify([...this.historyByPath.values()]));
    }

    async add(entry: HistoryEntry): Promise<void> {
        if (this.historyByPath.has(entry.path)) {
            // TODO - write an actual error
            throw new Error('');
        }

        this.historyByPath.set(entry.path, entry);
        await this.updateHistory();
    }

    async update(entry: HistoryEntry): Promise<void>;
    async update(path: string, updater: (entry: HistoryEntry) => HistoryEntry): Promise<void>;
    async update(entryOrPath: string | HistoryEntry, updater?: (entry: HistoryEntry) => HistoryEntry): Promise<void> {
        const path = typeof entryOrPath === 'string' ? entryOrPath : entryOrPath.path;

        if (!this.historyByPath.has(path)) {
            // TODO - write an actual error
            throw new Error('');
        }

        let entry;
        if (typeof entryOrPath === 'string') {
            if (updater == null) {
                // TODO - throw an actual error
                throw new Error('');
            }

            entry = updater(this.historyByPath.get(path)!);
        } else {
            entry = entryOrPath;
        }

        this.historyByPath.set(path, entry);
        await this.updateHistory();
    }

    async remove(entry: HistoryEntry): Promise<void> {
        this.historyByPath.delete(entry.path);
        await this.updateHistory();
    }

    async list(options?: IHistoryListOptions | undefined): Promise<HistoryEntry[]> {
        const entries = [...this.historyByPath.values()];

        if (options?.order === 'older') {
            entries.sort((a, b) => a.date - b.date);
        } else {
            entries.sort((a, b) => b.date - a.date);
        }

        if (options == null) {
            return entries;
        }

        const pred = optionsToPredicate(options);
        return entries.filter(pred);
    }

    static async create(): Promise<NeutralinoStorage> {
        try {
            const entries = JSON.parse(await Neutralino.storage.getData('history'));

            return new NeutralinoStorage(entries);
        } catch (err) {
            if (err.code === 'NE_ST_NOSTKEX') {
                return new NeutralinoStorage([]);
            }

            throw err;
        }
    }
}

class AnonymousStorage implements IHistoryStorage {

    storage: IHistoryStorage;

    constructor(storage: IHistoryStorage) {
        this.storage = storage;
    }

    add(_: HistoryEntry): Promise<void> {
        return Promise.resolve();
    }

    async update(entry: HistoryEntry): Promise<void>;
    async update(path: string, updater: (entry: HistoryEntry) => HistoryEntry): Promise<void>;
    async update(entryOrPath: string | HistoryEntry, updater?: (entry: HistoryEntry) => HistoryEntry): Promise<void> {
        return Promise.resolve();
    }

    remove(entry: HistoryEntry): Promise<void> {
        return this.storage.remove(entry);
    }

    list(options?: IHistoryListOptions | undefined): Promise<HistoryEntry[]> {
        return this.storage.list(options);
    }

}


export default class History {
    private static storage: IHistoryStorage | null = null;

    private static async default(): Promise<IHistoryStorage> {
        return await NeutralinoStorage.create();
    }

    private static async assertCreated(): Promise<void> {
        if (History.storage === null) {
            History.storage = await History.default();
        }
    }

    async setAnonymous(): Promise<void> {
        await History.assertCreated();

        if (!(History.storage instanceof AnonymousStorage)) {
            History.storage = new AnonymousStorage(History.storage!);
        }
    }

    async unsetAnonymous(): Promise<void> {
        await History.assertCreated();

        if (History.storage instanceof AnonymousStorage) {
            History.storage = History.storage.storage;
        }
    }

    static async add(entry: HistoryEntry): Promise<void> {
        await History.assertCreated();

        await History.storage!.add(entry);
    }

    static async update(entry: HistoryEntry): Promise<void>;
    static async update(path: string, updater: (entry: HistoryEntry) => HistoryEntry): Promise<void>;
    static async update(entryOrPath: string | HistoryEntry, updater?: (entry: HistoryEntry) => HistoryEntry): Promise<void> {
        await History.assertCreated();

        await History.storage!.update(entryOrPath, updater);
    }

    static async remove(entry: HistoryEntry): Promise<void> {
        await History.assertCreated();

        await History.storage!.remove(entry);
    }

    static async list(options?: IHistoryListOptions | undefined): Promise<HistoryEntry[]> {
        await History.assertCreated();

        return await History.storage!.list(options);
    }

    static async findByPath(path: string): Promise<HistoryEntry | undefined> {
        const hists = await History.list({
            path: {
                operation: 'equals',
                value: path,
                sensitive: true,
            },
        });

        return hists[0];
    }
}