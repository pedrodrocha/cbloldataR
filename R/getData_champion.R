#' Harvest data of champions in games of CBLOL from Leaguepedia
#'
#' Creates a tibble containing Leaguepedia data on champions played in CBLOL games
#'
#' @param Role (character) The lane where the champion was played. It should contain at least one of the five roles: "Top", "Jungle", "Mid", "AD Carry" and "Support".
#' @param Year (numeric) The year you want to access data (2015:2020).
#' @param Split (character) The split you want to access data: "Split 1", "Split 2", "Split 1 Playoffs" or "Split 2 Playoffs".
#' @param Champion (character) The champion you want to access data. By default it returns data on every champion. Its very case sensitive.
#'
#' @return A tibble containing: champion, number of games it was played, victories, defeats, win rate, kills, deaths, assists, KDA, CS per game, CS per minute, gold per game, gold per minute, kill participation, percentage of kills/team, percentage of gold/team, lane, year, split and league.
#' @export
#'
#' @examples
#' champion <- getData_champion(Role = "Mid", Year = 2020, Split = c("Split 2","Split 2 Playoffs"))
getData_champion <- function(Role, Year, Split, Champion = NULL){


  old <- options(warn = 0)
  options(warn = -1)

  if(!is.null(Champion)){
    if(typeof(Champion) != "character"){
      type <- typeof(Champion)

      rlang::abort(message = paste0("Champion should be character, not ", type),
                   class = "class error")
    }
  }

  if(typeof(Split) != "character"){
    type <- typeof(Split)

    rlang::abort(message = paste0("Split should be character, not ", type),
                 class = "class error")
  }


  if(typeof(Role) != "character"){
    type <- typeof(Role)

    rlang::abort(message = paste0("Role should be character, not ", type),
                 class = "class error")
  }

  if(is.numeric(Year) == FALSE){
    type <- typeof(Year)

    rlang::abort(message = paste0("Year should be numeric, not ", type),
                 class = "class error")
  }

  if(Year == 2021){
    rlang::abort(message = "The season hasn't started yet")
  }



  message("It may take a while...")



  url = "https://lol.gamepedia.com/Circuit_Brazilian_League_of_Legends"


  Split <- stringr::str_replace_all(Split," ","_")

  xml2::read_html(url) %>%
    rvest::html_nodes("td") %>%
    rvest::html_nodes("a") %>%
    rvest::html_attr("href") %>%
    tibble::as_tibble() %>%
    dplyr::filter(stringr::str_detect(value, "/CBLOL")) %>%
    dplyr::filter(stringr::str_detect(value, "Split")) %>%
    dplyr::filter(!stringr::str_detect(value, "Promotion")) %>%
    dplyr::filter(!stringr::str_detect(value, "Qualifiers")) %>%
    as.list() -> base_edicoes


  montagem_url_edicoes <- function(base){

    link <- paste0("https://lol.gamepedia.com",base)
    return(link)
  }


  links_edicoes <- purrr::map(base_edicoes,montagem_url_edicoes)
  links_edicoes <- purrr::flatten_chr(links_edicoes)

  links_edicoes %>%
    tibble::as_tibble() %>%
    dplyr::distinct() %>%
    purrr::flatten_chr() -> links_edicoes

  links_campeoes <- paste0(links_edicoes,"/Champion_Statistics")



  links_campeoes %>%
    tibble::as_tibble() %>%
    dplyr::mutate(
      ano = as.integer(stringr::str_extract(value, "[0-9]{4}")),
      split = stringr::str_extract(value, "Split(.*)"),
      split = stringr::str_remove(split, "/(.*)")
    ) %>%
    dplyr::filter(ano %in% Year) %>%
    dplyr::filter(split %in% Split) %>%
    dplyr::select(-ano, -split) %>%
    purrr::flatten_chr() -> links_campeoes

  ############ <<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>> ######################

  get_campeoes <- function(url, Roles = Role){

    url_lido <- xml2::read_html(url)

    url_lido %>%
      rvest::html_nodes("th") %>%
      rvest::html_nodes("table") %>%
      rvest::html_nodes("td") %>%
      rvest::html_nodes("a") %>%
      rvest::html_text() -> vector_roles


    links_por_role <- url_lido %>%
      rvest::html_nodes("th") %>%
      rvest::html_nodes("table") %>%
      rvest::html_nodes("td") %>%
      rvest::html_nodes("a") %>%
      rvest::html_attr("href")

    tibble::tibble(links = links_por_role,
                   role = vector_roles) -> links_por_role

    links_por_role %>%
      dplyr::filter(role %in% Roles) %>%
      dplyr::select(-role) %>%
      purrr::flatten_chr() -> links_por_role



    get_roles <- function(url_role) {


      xml2::read_html(url_role) %>%
        rvest::html_nodes("table") %>%
        rvest::html_table(fill = TRUE, header = FALSE) -> tab

      roles <- c("Top","Jungle","Mid","AD Carry","Support")

      role <- purrr::flatten_chr(stringr::str_extract_all(tab[[1]]$X1[1],roles))


      tab[[1]] %>%
        janitor::row_to_names(remove_row = TRUE, row_number = 3) %>%
        janitor::clean_names() %>%
        dplyr::na_if("-") %>%
        dplyr::mutate(role = role) -> dat


      return(dat)

    }

    dat2 <- purrr::map_dfr(links_por_role,get_roles)


    dat2 %>%
      dplyr::mutate(info = stringr::str_extract(url, "[0-9]{4}(.*)")) -> dat2

    dat2 %>%
      tidyr::separate(col = info,
               into = c("year","split"), sep = "/", remove = TRUE) %>%
      dplyr::mutate(year = stringr::str_extract(year, "[0-9]{4}")) -> dat2


    return(dat2)

  }


  campeoes <- purrr::map_dfr(links_campeoes,get_campeoes)



  campeoes <- campeoes %>%
    dplyr::mutate(g = as.numeric(g),
                  by = as.numeric(by),
                  w = as.numeric(w),
                  l = as.numeric(l),
                  k = as.numeric(k),
                  d = as.numeric(d),
                  a = as.numeric(a),
                  kda = as.numeric(kda),
                  cs = as.numeric(cs),
                  cs_m = as.numeric(cs_m),
                  g_2 = as.numeric(g_2),
                  g_m = as.numeric(g_m),
                  year = as.numeric(year))

  if(!is.null(Champion)){
    campeoes <- campeoes %>%
      tibble::as_tibble() %>%
      dplyr::filter(champion %in% Champion) %>%
      dplyr::mutate(league = "CBLOL")

    on.exit(options(old), add = TRUE)
    if (nrow(campeoes) == 0) {
      rlang::abort(message = "There is no data for this entry")
    }

    return(campeoes)

  } else{
    campeoes <- campeoes %>%
      tibble::as_tibble() %>%
      dplyr::mutate(league = "CBLOL")

    return(campeoes)
  }





}

