type ElmReceiver<T> = {
    subscribe: (subscription: (data: T) => void) => void,
};

type ElmSender<T> = {
    send: (data: T) => void,
}

type DefaultError = {
    code: string,
    message: string
};

type PageError = DefaultError & {
    page?: string,
};

type FallibleResult<TPayload, TError extends DefaultError = DefaultError> = {
    success: boolean,
    error?: TError,
    payload?: TPayload,
}

export type PageEntry = string | [string, string];

type HomePayload = undefined;
type ReadingPayload = string;

export type InitArgs = {
    node: HTMLElement,
    flags?: {
        screen: "home" | "read",
        payload: HomePayload | ReadingPayload,
    },
};

type NotifyPageChangePayload = {
    page: string,
    path: string,
};

type FileSelectedPayload = ReadingPayload;

type PageRequestPayload = {
    pages: string[],
    path: string
};

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

type PageResultPayload = {
    page: String,
    data: String
};

type CBChapter = {
    title?: string,
    number?: number,
    partial?: boolean,
    extra?: boolean,
    authors?: string[],
    artists?: string[],
    genres?: string[],
    themes?: string[],
    releaseDate?: number,
    tags?: string[],
    synopsis?: boolean,
    oneshot?: boolean,
};

export type CBInfo = {
    title: string,
    authors?: string[],
    artists?: string[],
    genres?: string[],
    themes?: string[],
    demographic?: "shounen" | "shoujo" | "seinen" | "josei" | "none",
    releaseDate?: number,
    endTime?: number,
    status?: "ongoing" | "completed" | "hiatus" | "cancelled",
    tags?: string[],
    synopsis?: string,
    oneshot?: boolean,
    chapters?: CBChapter[],
};

type CBFilePayload = {
    pages: string[],
    path: string,
    lastPageRead?: string,
    thumbnail?: string,
    info?: CBInfo,
};

type ElmApplication = {
    ports: {
        notifyPageChangePort: ElmReceiver<NotifyPageChangePayload>,
        requestFileSelectModalPort: ElmReceiver<void>,
        requestPagesPort: ElmReceiver<PageRequestPayload>,
        requestHistoryPort: ElmReceiver<void>,
        requestMetadataPort: ElmReceiver<string>,
        onFileSelectedPort: ElmSender<FileSelectedPayload>,
        onHistoryResultPort: ElmSender<FallibleResult<HistoryEntry[]>>,
        onMetadataResultPort: ElmSender<FallibleResult<CBFilePayload>>,
        onPageResultPort: ElmSender<FallibleResult<PageResultPayload, PageError>>,
    },
};

type ElmModule = {
    Main: {
        init: (args: InitArgs) => ElmApplication,
    },
};

declare var Elm: ElmModule;
export default Elm;