type ElmSubscription<T> = {
    subscribe: (subscription: (data: T) => void) => void,
};

type ElmSender<T> = {
    send: (data: T) => void,
}

type ReadEntry = {
    name: string,
    path: string,
    lastReadPage?: number,
};

export type PageEntry = string | [string, string];

type HomePayload = ReadEntry[];
type ReadingPayload = {
    name: string,
    path: string,
    pages: PageEntry[],
    currentPage?: number
};

export type InitArgs = {
    node: HTMLElement,
    flags?: {
        screen: "home" | "read",
        payload: HomePayload | ReadingPayload,
    },
};

type NotifyPageChangePayload = {
    currentPage: number,
    path: string,
};

type OnOpenFilePayload = ReadingPayload;

type ElmApplication = {
    ports: {
        notifyPageChangePort: ElmSubscription<NotifyPageChangePayload>,
        requestOpenFilePort: ElmSubscription<string>,
        onOpenFilePort: ElmSender<OnOpenFilePayload>,
        openFileSelectModalPort: ElmSubscription<void>,
    },
};

type ElmModule = {
    Main: {
        init: (args: InitArgs) => ElmApplication,
    },
};

declare var Elm: ElmModule;
export default Elm;