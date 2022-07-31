port module Ports exposing (..)

import Json.Decode as D
import Json.Encode as E


port notifyPageChangePort : E.Value -> Cmd msg


port requestOpenFilePort : String -> Cmd msg


port onOpenFilePort : (D.Value -> msg) -> Sub msg


port openFileSelectModalPort : () -> Cmd msg


type alias PageChangePayload =
    { currentPage : Int
    , path : String
    }


notifyPageChange : PageChangePayload -> Cmd msg
notifyPageChange payload =
    let
        encodedPayload =
            E.object
                [ ( "currentPage", E.int payload.currentPage )
                , ( "path", E.string payload.path )
                ]
    in
    notifyPageChangePort encodedPayload


requestOpenFile : String -> Cmd msg
requestOpenFile path =
    requestOpenFilePort path


onOpenFile : (D.Value -> msg) -> Sub msg
onOpenFile mapper =
    onOpenFilePort mapper


openFileSelectModal : Cmd msg
openFileSelectModal =
    openFileSelectModalPort ()
