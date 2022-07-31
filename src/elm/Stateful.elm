module Stateful exposing (..)


type Stateful succ err
    = NotAsked
    | Loading
    | Success succ
    | Failure err


map : (succA -> succB) -> Stateful succA err -> Stateful succB err
map mapper stateful =
    case stateful of
        Success succ ->
            Success <| mapper succ

        Failure err ->
            Failure err

        Loading ->
            Loading

        NotAsked ->
            NotAsked


mapFailure : (errA -> errB) -> Stateful succ errA -> Stateful succ errB
mapFailure mapper stateful =
    case stateful of
        Success succ ->
            Success succ

        Failure err ->
            Failure <| mapper err

        Loading ->
            Loading

        NotAsked ->
            NotAsked


hasRun : Stateful succ err -> Bool
hasRun stateful =
    case stateful of
        NotAsked ->
            False

        _ ->
            True


isLoading : Stateful succ err -> Bool
isLoading stateful =
    case stateful of
        Success _ ->
            True

        _ ->
            False


isFinished : Stateful succ err -> Bool
isFinished stateful =
    case stateful of
        Success _ ->
            True

        Failure _ ->
            True

        _ ->
            False


withDefault : succ -> Stateful succ err -> succ
withDefault default stateful =
    case stateful of
        Success succ ->
            succ

        _ ->
            default


toMaybe : Stateful succ err -> Maybe succ
toMaybe stateful =
    case stateful of
        Success succ ->
            Just succ

        _ ->
            Nothing
