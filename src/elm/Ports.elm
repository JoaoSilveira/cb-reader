port module Ports exposing (..)

import Converters
import Json.Decode as D
import Json.Encode as E
import Payloads


port notifyPageChangePort : E.Value -> Cmd msg


port requestFileSelectModalPort : () -> Cmd msg


port requestPagesPort : E.Value -> Cmd msg


port requestHistoryPort : () -> Cmd msg


port requestMetadataPort : String -> Cmd msg


port onFileSelectedPort : (String -> msg) -> Sub msg


port onHistoryResultPort : (D.Value -> msg) -> Sub msg


port onMetadataResultPort : (D.Value -> msg) -> Sub msg


port onPageResultPort : (D.Value -> msg) -> Sub msg


notifyPageChange : Payloads.PageChange -> Cmd msg
notifyPageChange payload =
    notifyPageChangePort <| Converters.pageChangeEncode payload


requestFileSelectModal : Cmd msg
requestFileSelectModal =
    requestFileSelectModalPort ()


requestPages : Payloads.PageRequest -> Cmd msg
requestPages payload =
    requestPagesPort <| Converters.pagesRequestEncode payload


requestHistory : Cmd msg
requestHistory =
    requestHistoryPort ()


requestMetadata : String -> Cmd msg
requestMetadata path =
    requestMetadataPort path


onFileSelected : (String -> msg) -> Sub msg
onFileSelected mapper =
    onFileSelectedPort mapper


onHistoryResult : (Payloads.PortResult Payloads.History -> msg) -> Sub msg
onHistoryResult mapper =
    onHistoryResultPort <| Converters.decodeFallible Converters.historyDecoder >> mapper


onMetadataResult : (Payloads.PortResult Payloads.CBFile -> msg) -> Sub msg
onMetadataResult mapper =
    onMetadataResultPort <| Converters.decodeFallible Converters.cbFileDecoder >> mapper


onPageResult : (Result Payloads.PageLoadError Payloads.PageLoaded -> msg) -> Sub msg
onPageResult mapper =
    let
        defaultError : Payloads.PageLoadError
        defaultError =
            { code = "DECODE_ERR", message = "A broken payload pass passed here, contact support", page = Nothing }
    in
    onPageResultPort <|
        Converters.decodeFallibleCustom
            Converters.pageLoadErrorDecoder
            defaultError
            Converters.pageLoadedDecoder
            >> mapper
