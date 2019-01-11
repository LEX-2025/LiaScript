module Lia.View exposing (view)

--import Html.Lazy exposing (lazy2)

import Array exposing (Array)
import Char
import Flip exposing (flip)
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events exposing (onClick, onInput)
import Html.Lazy as Lazy
import Lia.Definition.Types exposing (Definition, get_translations)
import Lia.Effect.Model exposing (current_paragraphs)
import Lia.Effect.View exposing (responsive, state)
import Lia.Helper exposing (ID)
import Lia.Index.Model as Index
import Lia.Index.View
import Lia.Markdown.Inline.Types exposing (Inlines)
import Lia.Markdown.Inline.View exposing (viewer)
import Lia.Markdown.View as Markdown
import Lia.Model exposing (Model, Toogler)
import Lia.Types exposing (..)
import Lia.Update exposing (Msg(..), Toggle(..), get_active_section)
import Translations exposing (..)


view : Model -> Html Msg
view model =
    Html.div
        (design model.design)
        [ view_aside model
        , view_article model
        ]


design : Design -> List (Html.Attribute msg)
design s =
    [ Attr.class
        ("lia-canvas lia-theme-"
            ++ s.theme
            ++ " lia-variant-"
            ++ s.light
        )
    , Attr.style "font-size" <| String.fromInt s.font_size ++ "%"
    ]


view_aside : Model -> Html Msg
view_aside model =
    Html.aside
        [ Attr.class "lia-toc"
        , Attr.style "max-width" <|
            if model.show.toc then
                "256px"

            else
                "0px"
        ]
        [ index_selector model.translation model.index_model
        , view_toc model.section_active model.index_model model.sections
        , settings model.show
            model.design
            (model
                |> get_active_section
                |> Maybe.andThen .definition
                |> Maybe.withDefault model.definition
            )
            (model.origin ++ "?" ++ model.readme)
            model.origin
            model.translation
        ]


index_selector : Lang -> Index.Model -> Html Msg
index_selector lang index_model =
    index_model
        |> Lia.Index.View.view lang
        |> Html.map UpdateIndex



{-
   view_aside : Model -> Html Msg
   view_aside model =
       Html.aside
           [ Attr.class "lia-toc"
           , Attr.style
               [ ( "max-width"
                 , if model.show.toc then
                       "256px"

                   else
                       "0px"
                 )
               ]
           ]
           [ index_selector model.translation model.index_model
           , model.sections
               |> index_list model.index_model.index
               |> view_toc model.section_active
           , settings model.show
               model.design
               (model
                   |> get_active_section
                   |> Maybe.andThen .definition
                   |> Maybe.withDefault model.definition
               )
               (model.origin ++ "?" ++ model.readme)
               model.origin
               model.translation
           ]






-}
{-
   to_secList sec =
       ( sec.title
       , sec.indentation
       , sec.visited
       , case sec.error of
           Nothing ->
               False

           _ ->
               True
       )
-}
{-
   index_list index sections =
       let
           titles =
               sections
                   |> Array.map to_secList
                   |> Array.toIndexedList

           fn ( idx, _ ) =
               List.member idx index
       in
       --    case index of
       --        [] ->
       titles
-}
--        _ ->
--            List.filter fn titles


settings : Toogler -> Design -> Definition -> String -> String -> Lang -> Html Msg
settings show design_ defines url origin lang =
    Html.div []
        [ Lazy.lazy3 view_settings lang show.settings design_
        , Lazy.lazy3 view_information lang show.informations defines
        , view_translations lang show.translations (origin ++ "?") (Lia.Definition.Types.get_translations defines)
        , Lazy.lazy2 qrCodeView show.share url
        , Html.div
            [ Attr.class "lia-settings", Attr.style "display" "inline-flex", Attr.style "width" "99%" ]
            [ dropdown show.settings "settings" (confSettings lang) (Toggle Settings)
            , dropdown show.informations "info" (confInformations lang) (Toggle Informations)
            , dropdown show.translations "translate" (confTranslations lang) (Toggle Translations)
            , dropdown show.share "share" (confShare lang) (Toggle Share)
            ]
        ]


dropdown : Bool -> String -> String -> Msg -> Html Msg
dropdown active name alt msg =
    Html.button
        [ onClick msg
        , Attr.class <|
            "lia-btn lia-icon"
                ++ (if active then
                        " lia-selected"

                    else
                        ""
                   )
        , Attr.title alt
        , Attr.style "width" "42px"
        , Attr.style "padding" "0px"
        ]
        [ Html.text name ]


view_settings : Lang -> Bool -> Design -> Html Msg
view_settings lang visible design_ =
    Html.div (menu_style visible)
        [ Html.p []
            [ Html.text <| cColor lang
            , view_design_light design_.light
            , design_theme lang design_
            , view_ace lang design_.ace
            , inc_font_size lang design_.font_size
            ]
        ]


inc_font_size : Lang -> Int -> Html Msg
inc_font_size lang int =
    Html.div []
        [ Html.text <| baseFont lang ++ ":"
        , navButton "-" (baseDec lang) (IncreaseFontSize False)
        , Html.text (String.fromInt int ++ "%")
        , navButton "+" (baseInc lang) (IncreaseFontSize True)
        ]


design_theme : Lang -> Design -> Html Msg
design_theme lang design_ =
    [ ( "default", "left", cDefault lang )
    , ( "amber", "right", cAmber lang )
    , ( "blue", "left", cBlue lang )
    , ( "green", "right", cGreen lang )
    , ( "grey", "left", cGray lang )
    , ( "purple", "right", cPurple lang )
    ]
        |> List.map (\( c, b, text ) -> check_list (c == design_.theme) c text b)
        |> Html.div [ Attr.class "lia-color" ]


view_information : Lang -> Bool -> Definition -> Html Msg
view_information lang visible definition =
    Html.div (menu_style visible)
        [ Html.p []
            [ Html.text <| infoAuthor lang
            , Html.text definition.author
            ]
        , Html.p []
            [ Html.text <| infoEmail lang
            , Html.a [ Attr.href definition.email ] [ Html.text definition.email ]
            ]
        , Html.p []
            [ Html.text <| infoVersion lang
            , Html.text definition.version
            ]
        , Html.p []
            [ Html.text <| infoDate lang
            , Html.text definition.date
            ]
        ]


view_translations : Lang -> Bool -> String -> List ( String, String ) -> Html Msg
view_translations lang visible base list =
    Html.div (menu_style visible) <|
        if List.isEmpty list then
            [ Html.text (no_translation lang) ]

        else
            list
                |> List.map
                    (\( lang_, url ) ->
                        Html.a
                            [ Attr.href (base ++ url) ]
                            [ Html.text lang_ ]
                    )


check_list : Bool -> String -> String -> String -> Html Msg
check_list checked label text dir =
    Html.label
        [ Attr.class label, Attr.style "float" dir ]
        [ Html.input
            [ Attr.type_ "radio"
            , Attr.name "toggle"
            , Attr.checked checked
            , onClick (DesignTheme label)
            ]
            []
        , Html.span
            []
            [ Html.text text ]
        ]


menu_style : Bool -> List (Html.Attribute msg)
menu_style visible =
    [ Attr.class <|
        "lia-slide-animation"
            ++ (if visible then
                    " lia-settings"

                else
                    ""
               )
    , Attr.style "max-height" <|
        if visible then
            "256px"

        else
            "0px"
    ]


qrCodeView : Bool -> String -> Html msg
qrCodeView visible url =
    Html.div (menu_style visible)
        [ Html.p []
            [ Html.img
                [ Attr.src ("https://api.qrserver.com/v1/create-qr-code/?size=222x222&data=" ++ url)
                , Attr.style "width" "99%"
                ]
                []
            ]
        ]


view_toc : ID -> Index.Model -> Sections -> Html Msg
view_toc active index sections =
    let
        toc_ =
            toc active
    in
    sections
        |> Array.toIndexedList
        |> Index.filter index
        |> List.map toc_
        |> Html.div [ Attr.class "lia-content" ]


toc : ID -> ( ID, Section ) -> Html Msg
toc active ( idx, section ) =
    Html.a
        [ --onClick (Load idx)
          Attr.class
            ("lia-toc-l"
                ++ String.fromInt section.indentation
                ++ (if section.error /= Nothing then
                        " lia-error"

                    else if active == idx then
                        " lia-active"

                    else if section.visited then
                        ""

                    else
                        " lia-not-visited"
                   )
            )
        , Attr.href ("#" ++ String.fromInt (idx + 1))
        ]
        (viewer 9999 section.title)


view_article : Model -> Html Msg
view_article model =
    Html.article [ Attr.class "lia-slide" ] <|
        case get_active_section model of
            Just section ->
                [ section
                    |> .effect_model
                    |> state
                    |> view_nav model.section_active model.mode model.translation model.design model.url (get_translations model.definition)
                , Html.map UpdateMarkdown <| Markdown.view model.translation model.mode section model.design.ace
                , view_footer model.translation model.sound model.mode section.effect_model
                ]

            Nothing ->
                [ Html.text "" ]


view_footer : Lang -> Bool -> Mode -> Lia.Effect.Model.Model -> Html Msg
view_footer lang sound mode effects =
    case mode of
        Slides ->
            effects
                |> current_paragraphs
                |> List.map (\( _, par ) -> Html.p [] (viewer 9999 par))
                |> flip List.append [ responsive lang sound (Toggle Sound) ]
                |> Html.footer [ Attr.class "lia-footer" ]

        Presentation ->
            Html.footer [ Attr.class "lia-footer" ] [ responsive lang sound (Toggle Sound) ]

        Textbook ->
            Html.text ""


navButton : String -> String -> msg -> Html msg
navButton str title msg =
    Html.button
        [ onClick msg
        , Attr.title title
        , Attr.class "lia-btn lia-slide-control lia-left"
        ]
        [ Html.text str ]


view_nav : ID -> Mode -> Lang -> Design -> String -> List ( String, String ) -> ( Bool, String ) -> Html Msg
view_nav section_active mode lang design_ base translations ( speaking, state ) =
    Html.nav [ Attr.class "lia-toolbar" ]
        [ Html.button
            [ onClick (Toggle TOC)
            , Attr.title (baseToc lang)
            , Attr.class "lia-btn lia-toc-control lia-left"
            ]
            [ Html.text "toc" ]
        , Html.span [ Attr.class "lia-spacer" ] []
        , navButton "navigate_before" (basePrev lang) PrevSection
        , Html.span [ Attr.class "lia-labeled lia-left" ]
            [ Html.span
                [ Attr.class "lia-label"
                , if speaking then
                    Attr.style "text-decoration" "underline"

                  else
                    Attr.style "" ""
                ]
                [ Html.text (String.fromInt (section_active + 1))
                , Html.text <|
                    case mode of
                        Textbook ->
                            ""

                        _ ->
                            " " ++ state
                ]
            ]
        , navButton "navigate_next" (baseNext lang) NextSection
        , Html.span [ Attr.class "lia-spacer" ] []
        , Html.button
            [ Attr.class "lia-btn lia-right"
            , onClick SwitchMode
            , Attr.title <|
                case mode of
                    Slides ->
                        modeSlides lang

                    Presentation ->
                        modePresentation lang

                    Textbook ->
                        modeTextbook lang
            ]
            [ Html.text <|
                case mode of
                    Slides ->
                        "visibility"

                    Presentation ->
                        "hearing"

                    Textbook ->
                        "book"
            ]
        ]


capitalize : String -> String
capitalize s =
    case String.uncons s of
        Just ( c, ss ) ->
            String.cons (Char.toUpper c) ss

        Nothing ->
            s


view_design_light : String -> Html Msg
view_design_light light =
    Html.span
        [ Attr.class "lia-btn"
        , onClick DesignLight
        , Attr.style "text-align" "right"
        ]
        [ if light == "light" then
            Html.text "🌞"

          else
            Html.text "🌝"
        ]


option : String -> ( String, String ) -> Html Msg
option current ( val, text ) =
    Html.option [ Attr.value val, Attr.selected (val == current) ] [ Html.text text ]


view_ace : Lang -> String -> Html Msg
view_ace lang theme =
    let
        op =
            option theme
    in
    Html.div [ Attr.style "display" "inline-flex", Attr.style "width" "99%" ]
        [ Html.select [ onInput DesignAce ]
            [ [ ( "chrome", "Chrome" )
              , ( "clouds", "Clouds" )
              , ( "crimson_editor", "Crimson Editor" )
              , ( "dawn", "Dawn" )
              , ( "dreamweaver", "Dreamweaver" )
              , ( "eclipse", "Eclipse" )
              , ( "github", "Github" )
              , ( "iplastic", "IPlastic" )
              , ( "solarized_light", "Solarized Light" )
              , ( "textmate", "TextMate" )
              , ( "tomorrow", "Tomorrow" )
              , ( "xcode", "XCode" )
              , ( "kuroir", "Kuroir" )
              , ( "katzenmilch", "KatzenMilch" )
              , ( "sqlserver", "SQL Server" )
              ]
                |> List.map op
                |> Html.optgroup [ Attr.attribute "label" (cBright lang) ]
            , [ ( "ambiance", "Ambiance" )
              , ( "chaos", "Chaos" )
              , ( "clouds_midnight", "Clouds Midnight" )
              , ( "dracula", "Dracula" )
              , ( "cobalt", "Cobalt" )
              , ( "gruvbox", "Gruvbox" )
              , ( "gob", "Green on Black" )
              , ( "idle_fingers", "idle Fingers" )
              , ( "kr_theme", "krTheme" )
              , ( "merbivore", "Merbivore" )
              , ( "merbivore_soft", "Merbivore Soft" )
              , ( "mono_industrial", "Mono Industrial" )
              , ( "monokai", "Monokai" )
              , ( "pastel_on_dark", "Pastel on dark" )
              , ( "solarized_dark", "Solarized Dark" )
              , ( "terminal", "Terminal" )
              , ( "tomorrow_night", "Tomorrow Night" )
              , ( "tomorrow_night_blue", "Tomorrow Night Blue" )
              , ( "tomorrow_night_bright", "Tomorrow Night Bright" )
              , ( "tomorrow_night_eighties", "Tomorrow Night 80s" )
              , ( "twilight", "Twilight" )
              , ( "vibrant_ink", "Vibrant Ink" )
              ]
                |> List.map op
                |> Html.optgroup [ Attr.attribute "label" (cDark lang) ]
            ]
        ]



{- "Bright">


   <optgroup label="Dark">

-}