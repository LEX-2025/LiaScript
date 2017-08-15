module Lia.Update exposing (update)

import Array
import Lia.Model exposing (..)
import Lia.Type exposing (..)
import Tts.Tts exposing (speak)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Load int ->
            --( { model | slide = int }, Cmd.none )
            update (Speak "Starting to load next slide") { model | slide = int }

        CheckBox quiz_id question_id ->
            ( { model | quiz = flip_checkbox quiz_id question_id model.quiz }, Cmd.none )

        Check quiz_id ->
            ( { model | quiz = check_answer quiz_id model.quiz }, Cmd.none )

        Speak text ->
            ( { model | error = "Speaking" }, speak TTS Nothing "en_US" text )

        TTS (Result.Ok _) ->
            ( { model | error = "" }, Cmd.none )

        TTS (Result.Err m) ->
            ( { model | error = m }, Cmd.none )


flip_checkbox : Int -> Int -> QuizMatrix -> QuizMatrix
flip_checkbox quiz_id question_id matrix =
    case Array.get quiz_id matrix of
        Just ( state, quiz ) ->
            case state of
                Just True ->
                    matrix

                _ ->
                    case Array.get question_id quiz of
                        Just question ->
                            question
                                |> (\( c, a ) -> ( not c, a ))
                                |> (\q -> Array.set question_id q quiz)
                                |> (\q -> Array.set quiz_id ( state, q ) matrix)

                        Nothing ->
                            matrix

        Nothing ->
            matrix


check_answer : Int -> QuizMatrix -> QuizMatrix
check_answer quiz_id matrix =
    case Array.get quiz_id matrix of
        Just ( Just True, _ ) ->
            matrix

        Just ( state, quiz ) ->
            let
                f ( c, a ) r =
                    r && (c == a)

                answer =
                    Just (Array.foldr f True quiz)

                a =
                    Debug.log "anser"

                b =
                    Debug.log <| toString answer
            in
            Array.set quiz_id ( answer, quiz ) matrix

        Nothing ->
            matrix
