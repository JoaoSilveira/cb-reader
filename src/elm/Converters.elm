module Converters exposing (..)

import Json.Decode as D
import Json.Decode.Pipeline as P
import Json.Encode as E
import Payloads
import Time exposing (Posix)


errorPayloadDecoder : D.Decoder Payloads.ErrorPayload
errorPayloadDecoder =
    D.map2
        Payloads.ErrorPayload
        (D.field "code" D.string)
        (D.field "message" D.string)


pageLoadErrorDecoder : D.Decoder Payloads.PageLoadError
pageLoadErrorDecoder =
    D.map3
        Payloads.PageLoadError
        (D.field "code" D.string)
        (D.field "message" D.string)
        (D.field "page" <| D.map Just D.string)


decodeFallible : D.Decoder payload -> D.Value -> Payloads.PortResult payload
decodeFallible payloadDecoder value =
    let
        defaultError : Payloads.ErrorPayload
        defaultError =
            { code = "DECODE_ERR", message = "A broken payload pass passed here, contact support" }
    in
    decodeFallibleCustom errorPayloadDecoder defaultError payloadDecoder value


decodeFallibleCustom : D.Decoder error -> error -> D.Decoder payload -> D.Value -> Result error payload
decodeFallibleCustom errorDecoder defaultError payloadDecoder value =
    let
        resolvePayloadType : Bool -> D.Decoder (Result error payload)
        resolvePayloadType success =
            if success then
                D.map Ok <| D.field "payload" payloadDecoder

            else
                D.map Err <| D.field "error" errorDecoder

        decoder : D.Decoder (Result error payload)
        decoder =
            D.field "success" D.bool
                |> D.andThen resolvePayloadType
    in
    D.decodeValue decoder value
        |> Result.withDefault (Err defaultError)


optionalPageDecoder : String -> D.Decoder Int
optionalPageDecoder fieldName =
    D.maybe (D.field fieldName D.int)
        |> D.andThen (Maybe.withDefault 1 >> D.succeed)


pagesRequestEncode : Payloads.PageRequest -> E.Value
pagesRequestEncode payload =
    E.object
        [ ( "pages", E.list E.string payload.pages )
        , ( "path", E.string payload.path )
        ]


pageChangeEncode : Payloads.PageChange -> E.Value
pageChangeEncode payload =
    E.object
        [ ( "currentPage", E.int payload.currentPage )
        , ( "path", E.string payload.path )
        ]


historyDecoder : D.Decoder Payloads.History
historyDecoder =
    D.map5
        Payloads.HistoryEntry
        (D.field "title" D.string)
        (D.field "author" D.string)
        (D.maybe (D.field "chapter" D.int))
        (D.field "page" D.int)
        (D.field "path" D.string)
        |> D.list


dateDecoder : D.Decoder Posix
dateDecoder =
    D.map Time.millisToPosix D.int


pageLoadedDecoder : D.Decoder Payloads.PageLoaded
pageLoadedDecoder =
    D.map2
        Payloads.PageLoaded
        (D.field "page" D.string)
        (D.field "data" D.string)


demographicDecoder : D.Decoder Payloads.Demographic
demographicDecoder =
    let
        tryFindTag : String -> D.Decoder Payloads.Demographic
        tryFindTag tag =
            case tag of
                "shounen" ->
                    D.succeed Payloads.Shounen

                "shoujo" ->
                    D.succeed Payloads.Shoujo

                "seinen" ->
                    D.succeed Payloads.Seinen

                "josei" ->
                    D.succeed Payloads.Josei

                "none" ->
                    D.succeed Payloads.None

                _ ->
                    D.fail tag
    in
    D.andThen tryFindTag D.string


publishingStatusDecoder : D.Decoder Payloads.PublicationStatus
publishingStatusDecoder =
    let
        tryFindTag : String -> D.Decoder Payloads.PublicationStatus
        tryFindTag tag =
            case tag of
                "ongoing" ->
                    D.succeed Payloads.Ongoing

                "completed" ->
                    D.succeed Payloads.Completed

                "hiatus" ->
                    D.succeed Payloads.Hiatus

                "cancelled" ->
                    D.succeed Payloads.Cancelled

                _ ->
                    D.fail tag
    in
    D.andThen tryFindTag D.string


cbChapterDecoder : D.Decoder Payloads.CBChapter
cbChapterDecoder =
    D.succeed Payloads.CBChapter
        |> P.custom (D.maybe (D.field "title" D.string))
        |> P.custom (D.maybe (D.field "number" D.float))
        |> P.custom (D.oneOf [ D.field "partial" D.bool, D.succeed False ])
        |> P.custom (D.oneOf [ D.field "extra" D.bool, D.succeed False ])
        |> P.custom (D.maybe (D.field "authors" (D.list D.string)))
        |> P.custom (D.maybe (D.field "artists" (D.list D.string)))
        |> P.custom (D.maybe (D.field "genres" (D.list D.string)))
        |> P.custom (D.maybe (D.field "themes" (D.list D.string)))
        |> P.custom (D.maybe (D.field "releaseDate" dateDecoder))
        |> P.custom (D.maybe (D.field "tags" (D.list D.string)))
        |> P.custom (D.maybe (D.field "synopsis" D.string))
        |> P.custom (D.oneOf [ D.field "oneshot" D.bool, D.succeed False ])


cbInfoDecoder : D.Decoder Payloads.CBInfo
cbInfoDecoder =
    D.succeed Payloads.CBInfo
        |> P.custom (D.field "title" D.string)
        |> P.custom (D.maybe (D.field "authors" (D.list D.string)))
        |> P.custom (D.maybe (D.field "artists" (D.list D.string)))
        |> P.custom (D.maybe (D.field "genres" (D.list D.string)))
        |> P.custom (D.maybe (D.field "themes" (D.list D.string)))
        |> P.custom (D.maybe (D.field "demographic" demographicDecoder))
        |> P.custom (D.maybe (D.field "releaseDate" dateDecoder))
        |> P.custom (D.maybe (D.field "endTime" dateDecoder))
        |> P.custom (D.maybe (D.field "status" publishingStatusDecoder))
        |> P.custom (D.maybe (D.field "tags" (D.list D.string)))
        |> P.custom (D.maybe (D.field "synopsis" D.string))
        |> P.custom (D.oneOf [ D.field "oneshot" D.bool, D.succeed False ])
        |> P.custom (D.maybe (D.field "chapters" (D.list cbChapterDecoder)))


cbFileDecoder : D.Decoder Payloads.CBFile
cbFileDecoder =
    D.map5
        Payloads.CBFile
        (D.field "pages" <| D.array D.string)
        (D.field "path" D.string)
        (D.maybe (D.field "lastPageRead" D.string))
        (D.maybe (D.field "thumbnail" D.string))
        (D.maybe (D.field "info" cbInfoDecoder))
