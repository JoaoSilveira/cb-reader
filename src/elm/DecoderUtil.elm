module DecoderUtil exposing (..)

import Json.Decode as D


optionalPageDecoder : String -> D.Decoder Int
optionalPageDecoder fieldName =
    D.maybe (D.field fieldName D.int)
        |> D.andThen (Maybe.withDefault 1 >> D.succeed)
