USE Covid19
------------------------------------------------------------
-- Check if the data is loaded correctly for covid deaths --
------------------------------------------------------------
SELECT 
	* 
FROM
	Covid19..['CovidDeaths']
ORDER BY
	location, date

------------------------------------------------------------
-- Check if the data is loaded correctly for covid vaccinations 
------------------------------------------------------------
SELECT 
	* 
FROM 
	Covid19..['CovidVaccinations']
ORDER BY
	location, date


------------------------------------------------------------
-- Select the data we need
------------------------------------------------------------
SELECT 
	location, date, total_cases, new_cases, total_deaths, population 
FROM 
	Covid19..['CovidDeaths']
ORDER BY
	location, date
----------------------------------------------------------------
-- We have some incorrect data like "Africa" etc in the location and I noticed that those continents all have an iso_code that starts with OWID so we can remove them
----------------------------------------------------------------

-- 1/ Global cases, deaths, death rate 

SELECT
  SUM(new_cases) as global_cases, SUM(CAST(new_deaths as int)) as global_deaths, SUM(CAST(new_deaths as int))/SUM(new_cases)*100 as global_death_rate
FROM
	Covid19..['CovidDeaths']
WHERE 
	iso_code not like '%OWID%'


-- 2/ Average Percentage of death related to cases in each country
SELECT 
	location, AVG((total_deaths/total_cases) * 100) as percentage_death
FROM 
    Covid19..['CovidDeaths']
WHERE
	iso_code not like '%OWID%'
GROUP BY 
	location
ORDER BY
	location


-- 3/ Percentage of death related to cases in each country through days
SELECT 
	location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 as percentage_death
FROM 
    Covid19..['CovidDeaths'] 
ORDER BY
	location, date


-- 4/ Percentage of death related to cases in each country through days in Algeria
-- We can deduce the likelihood of a person dying in Algeria 
SELECT 
	location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 as percentage_death
FROM 
    Covid19..['CovidDeaths'] 
WHERE 
	location like '%Algeria%' AND iso_code not like '%OWID%'
ORDER BY
	location, date


-- 5/ Percentage of death related to cases in each country through days in US
SELECT 
	location, date, total_cases, total_deaths, (total_deaths/total_cases) * 100 as percentage_death
FROM 
    Covid19..['CovidDeaths'] 
WHERE 
	location like '%states%' AND iso_code not like '%OWID%'
ORDER BY
	location, date


-- 6/ Percentage of total cases vs the population
-- Shows the percentage of population who go covid through time in the United States from the beginning to February 1st 2022
SELECT
	location, date, total_cases, population, (total_cases/population)*100 as percentage_cases
FROM
		Covid19..['CovidDeaths']
WHERE 
	location like '%states%' AND iso_code not like '%OWID%'
GROUP BY 
	location, date, total_cases, population
ORDER BY
    date


-- 7/ The countries with highest infection rate
SELECT
	location, population, MAX(total_cases) as highest_infection_cases, MAX(total_cases/population)*100 as percentage_cases
FROM
	Covid19..['CovidDeaths']
WHERE 
	iso_code not like '%OWID%'
GROUP BY 
	location, population
ORDER BY
	percentage_cases DESC


-- 8/ The countries with highest deaths
SELECT
	location, population, MAX(CAST(total_deaths AS FLOAT)) as highest_deaths, MAX(CAST(total_deaths AS FLOAT)/population)*100 as percentage_death
FROM
	Covid19..['CovidDeaths']
WHERE 
	iso_code not like '%OWID%'
GROUP BY 
	location, population
ORDER BY
	highest_deaths DESC


-- 9/ Continents with highest death 
SELECT
	location, MAX(CAST(total_deaths AS FLOAT)) as highest_deaths
FROM
	Covid19..['CovidDeaths']
WHERE 
	location in ('Asia','Africa','Oceania','Europe','South America', 'North America')
GROUP BY 
	location
ORDER BY
	highest_deaths DESC

-- 10/ Global new cases, new deaths and the death rate for infected people

SELECT
	date, SUM(new_cases) as global_cases, SUM(CAST(new_deaths as int)) as global_deaths, SUM(CAST(new_deaths as int))/SUM(new_cases)*100 as global_death_rate
FROM
	Covid19..['CovidDeaths']
WHERE 
	iso_code not like '%OWID%'
GROUP BY 
	date
ORDER BY
	date
	
-- Total Population VS Vaccinations

SELECT
	dea.continent, dea.location, population, SUM(CAST(new_vaccinations as FLOAT )) as total_vaccinations, SUM(CAST(new_vaccinations as FLOAT ))  / population * 100 as vaccination_rate
FROM
	Covid19..['CovidDeaths'] dea 
JOIN 
	Covid19..['CovidVaccinations'] vac
ON	
	dea.location = vac.location AND dea.date = vac.date AND dea.iso_code = vac.iso_code
WHERE 
	dea.iso_code not like '%OWID%'
GROUP BY
	dea.continent, dea.location, population
ORDER BY 
	dea.location


-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine
SELECT
	dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
	, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (PARTITION BY  dea.Location ORDER BY dea.location, dea.Date) as rolling_people_vaccinated
FROM
	Covid19..['CovidDeaths'] dea
JOIN
	Covid19..['CovidVaccinations'] vac
ON
	dea.location = vac.location AND dea.date = vac.date
WHERE 
	dea.iso_code not like '%OWID%'
ORDER BY 
	dea.location, dea.date

-- For the percentage we need to make the previous query a CTE first

WITH 
	Population_vs_Vaccination (continent, location, date, population, new_vaccinations, rolling_people_vaccinated)
AS
(SELECT
	dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
	, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (PARTITION BY  dea.Location ORDER BY dea.location, dea.Date) as rolling_people_vaccinated
FROM
	Covid19..['CovidDeaths'] dea
JOIN
	Covid19..['CovidVaccinations'] vac
ON
	dea.location = vac.location AND dea.date = vac.date
WHERE 
	dea.iso_code not like '%OWID%')
SELECT 
	*, (rolling_people_vaccinated/ population)*100 as vaccination_rate
FROM
	Population_vs_Vaccination

-- We can also make it with a temporar table

DROP Table IF EXISTS #PercentagePopulationVaccinated
Create Table #PercentagePopulationVaccinated
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rolling_people_vaccinated numeric
)

INSERT INTO #PercentagePopulationVaccinated 
SELECT
	dea.continent, dea.location, dea.date, CONVERT(numeric, dea.population), CONVERT(bigint,vac.new_vaccinations)
	, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (PARTITION BY  dea.Location ORDER BY dea.location, dea.Date) as rolling_people_vaccinated
FROM
	Covid19..['CovidDeaths'] dea
JOIN
	Covid19..['CovidVaccinations'] vac
ON
	dea.location = vac.location AND dea.date = vac.date
WHERE 
	dea.iso_code not like '%OWID%'


SELECT
	*
FROM 
	#PercentagePopulationVaccinated
ORDER BY
	location, date

-- We can also make it with a View

CREATE VIEW PercentPopulationVaccinated AS 
SELECT
	dea.continent, dea.location, dea.date, CONVERT(numeric, dea.population) as population, CONVERT(bigint,vac.new_vaccinations) as new_vaccination
	, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (PARTITION BY  dea.Location ORDER BY dea.location, dea.Date) as rolling_people_vaccinated
FROM
	Covid19..['CovidDeaths'] dea
JOIN
	Covid19..['CovidVaccinations'] vac
ON
	dea.location = vac.location AND dea.date = vac.date
WHERE 
	dea.iso_code not like '%OWID%'


SELECT
	*
FROM 
	PercentPopulationVaccinated
ORDER BY
	location, date
