--EDA:

SELECT *
FROM allstarfull;


SELECT *
FROM appearances
ORDER BY yearid DESC;


SELECT *
FROM awardsmanagers ;


SELECT *
FROM awardssharemanagers ;


SELECT *
FROM awardsshareplayers ;


SELECT *
FROM batting ;


SELECT *
FROM collegeplaying  ;


SELECT *
FROM fielding ;


SELECT *
FROM fieldingofsplit ;



SELECT *
FROM fieldingpost ;



SELECT *
FROM halloffame ;



SELECT *
FROM homegames ;



SELECT *
FROM managers ;



SELECT *
FROM managershalf ;



SELECT *
FROM parks  ;



SELECT *
FROM people ;



SELECT *
FROM pitching ;



SELECT *
FROM pitchingpost ;



SELECT *
FROM salaries  ;



SELECT *
FROM schools ;



SELECT *
FROM seriespost ;



SELECT *
FROM teams 
WHERE yearid >= 1970 AND yearid <= 2016 AND (WSWin IS NULL OR W IS NULL)
ORDER BY w DESC
;



-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?


SELECT 
	vp.namefirst AS "First Name",
	vp.namelast AS "Last Name",
	COALESCE(SUM(s.salary), 0) AS "Total Salary"
FROM
	(SELECT DISTINCT p.playerid, p.namefirst, p.namelast
	FROM people AS p
	INNER JOIN collegeplaying AS cp 
		USING (playerid)
	INNER JOIN schools AS sc 
		USING (schoolid)  
	WHERE sc.schoolname = 'Vanderbilt University') AS vp
LEFT JOIN salaries AS s
	USING (playerid)
GROUP BY vp.playerid, vp.namefirst, vp.namelast
HAVING SUM(s.salary) IS NOT NULL
ORDER BY SUM(s.salary) DESC;

--Ans: David Price, $81,851,296


 
--What NOT to do: the following query contains a 1-to-many join with collegeplaying which will then count the affected players' salaries multiple times (via SUM() ).

SELECT pp.playerid, namefirst, namelast, COALESCE(SUM(salary), 0) AS Total_Salary
FROM people AS pp
INNER JOIN collegeplaying
	USING (playerid)
INNER JOIN schools
	USING (schoolid)
INNER JOIN salaries AS sal  
	USING (playerid)
WHERE schoolname = 'Vanderbilt University'
GROUP BY pp.playerid
ORDER BY Total_Salary DESC 
;




--2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

 
SELECT 
SUM((CASE WHEN pos = 'OF' THEN po ELSE 0 END)) AS Outfield_PO, 
SUM((CASE WHEN pos in ('SS','1B','3B') THEN po ELSE 0 END)) AS Infield_PO, 
SUM((CASE WHEN pos in ('P', 'C') THEN po ELSE 0 END)) AS Battery_PO 
FROM people AS pp
INNER JOIN fielding AS f 
	USING (playerid)
WHERE yearid = 2016
;



--3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the generate_series function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)



--Strike Outs:

WITH bins AS(
	SELECT generate_series(1920, 2010, 10) AS lower_bound_decade,
			generate_series(1930, 2020, 10) AS upper_bound_decade
)
SELECT lower_bound_decade, upper_bound_decade, SUM(so) AS Strike_Outs, SUM(g) AS Games_played , ROUND((SUM(so*1.0) / SUM(g))/2, 2) AS Avg_Num_of_Strike_Outs_per_Games_Played
	FROM Teams AS t
		RIGHT JOIN bins 
			ON yearid >= lower_bound_decade
			AND yearid < upper_bound_decade 
WHERE yearid >= 1920
GROUP BY lower_bound_decade, upper_bound_decade  
ORDER BY lower_bound_decade
;


--Homeruns:

WITH bins AS(
	SELECT generate_series(1920, 2010, 10) AS lower_bound_decade,
			generate_series(1930, 2020, 10) AS upper_bound_decade
)
SELECT lower_bound_decade, upper_bound_decade, SUM(hr) AS Homeruns_by_batters, SUM(g) AS Games_played, ROUND((SUM(hr*1.0) / SUM(g))/2, 2) AS Avg_Num_of_Homeruns_by_batters_per_Games_Played
	FROM Teams AS t
		RIGHT JOIN bins 
			ON yearid >= lower_bound_decade
			AND yearid < upper_bound_decade 
WHERE yearid >= 1920
GROUP BY lower_bound_decade, upper_bound_decade  
ORDER BY lower_bound_decade
; 



--4. Find the player who had the most success stealing bases in 2016, where success is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted at least 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.


--best, most accurate, and most robust solution:
SELECT namegiven, namefirst, namelast, SUM(sb) AS Total_Stolen_Bases, SUM(cs) AS Total_Caught_Stealing, SUM(sb) + SUM(cs) AS Total_Attempts, SUM(sb)*100.0 / (SUM(sb) + SUM(cs)) AS stealing_pct
FROM people AS pp
LEFT JOIN batting AS b ON pp.playerid = b.playerid
WHERE yearid = 2016
GROUP BY namegiven, namefirst, namelast
HAVING SUM(sb) + SUM(cs) >= 20
ORDER BY stealing_pct DESC
;


--a less robust solution:
SELECT playerid, namefirst, namelast, SB*100.0 / (SB + CS) AS Percentage_of_Successful_Attempts_to_Steal_Bases
FROM people AS p
INNER JOIN batting AS b
	USING (playerid)
WHERE yearid = 2016 AND (SB + CS) >= 20
GROUP BY playerid, b.SB, b.CS
ORDER BY Percentage_of_Successful_Attempts_to_Steal_Bases DESC
;




--5a. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series?
--5b. What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year.  


--Initial exploratory steps:

SELECT teamID, WSWin, SUM(W) AS Total_Wins
FROM teams AS t
WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'N'
GROUP BY teamID, WSWin
ORDER BY Total_Wins DESC
;

SELECT teamID, WSWin, W AS Yearly_Wins
FROM teams AS t
WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'Y'
ORDER BY Yearly_Wins
;



--EDA: 1994 is the problem year in which the WSWin column has NULLs. 1981 has a shortened season, due to strike. 

SELECT *
FROM teams 
WHERE yearid >= 1970 AND yearid <= 2016 AND (WSWin IS NULL OR W IS NULL)
ORDER BY w DESC
;


--Excluding year 1994:

SELECT teamID, yearID, WSWin, W AS Yearly_Wins
FROM teams AS t
WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'Y' AND yearid != 1994
ORDER BY Yearly_Wins
;
--Ans: 63


SELECT teamID, yearID, WSWin, W AS Yearly_Wins
FROM teams AS t
WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'N' AND yearid != 1994
ORDER BY Yearly_Wins DESC
;
--5a Ans: 116


--5c. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

WITH CTE1 AS (
	SELECT teamID, yearID, WSWin, W AS Yearly_Wins
	FROM teams AS t
	WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'Y' AND yearid != 1994 AND yearid != 1981
	ORDER BY yearID
),
CTE2 AS (
	SELECT yearID, MAX(W) AS Most_Yearly_Wins
	FROM teams AS t
	WHERE yearid >= 1970 AND yearid <= 2016 AND yearid != 1994 AND yearid != 1981
	GROUP BY yearID 
	ORDER BY yearID
),
CTE3 AS (
	SELECT c2.yearID, c2.Most_Yearly_Wins, t.teamid
	FROM teams AS t
	INNER JOIN CTE2 AS C2 ON t.yearID = c2.yearID AND t.W = c2.Most_Yearly_Wins 
	WHERE t.yearid >= 1970 AND t.yearid <= 2016 AND t.yearid != 1994 AND t.yearid != 1981
	GROUP BY c2.yearID, c2.Most_Yearly_Wins, t.teamid 
	ORDER BY c2.yearID
)
SELECT count(*) * 100.0 / (SELECT count(*) FROM CTE2) AS Percentage_of_Winning_the_WS
FROM CTE3
INNER JOIN CTE1
	USING (yearID, teamID) 
;

-- If we are to only assess the result from a yearly binary perspective, then we see 
-- Ans 1: 12/46 = 26.1%, if we're only excluding year 1994 : Out of the 46 teams that are the top yearly winners, 12 teams also won the World Series in the same year.  
-- Ans 2: Since year 1994 doesn't have WS data and year 1981 was shortened by strike, 12/45 = 26.6667% is the answer when we exclude both 1994 and 1981. 

-- If we're to assess the results from a teams' perspective , we see 12 out of 52 teams with most yearly wins also won the World Series in the same year = 23.077% if we only exclude year 1994.
-- 23.53% if we also exclude year 1981



WITH CTE1 AS (
	SELECT teamID, yearID, WSWin, W AS Yearly_Wins
	FROM teams AS t
	WHERE yearid >= 1970 AND yearid <= 2016 AND WSWin = 'Y' AND yearid != 1994 AND yearid != 1981
	ORDER BY yearID
),
CTE2 AS (
	SELECT yearID, MAX(W) AS Most_Yearly_Wins
	FROM teams AS t
	WHERE yearid >= 1970 AND yearid <= 2016 AND yearid != 1994 AND yearid != 1981
	GROUP BY yearID 
	ORDER BY yearID
),
CTE3 AS (
	SELECT c2.yearID, c2.Most_Yearly_Wins, t.teamid
	FROM teams AS t
	INNER JOIN CTE2 AS C2 ON t.yearID = c2.yearID AND t.W = c2.Most_Yearly_Wins 
	WHERE t.yearid >= 1970 AND t.yearid <= 2016 AND t.yearid != 1994 AND t.yearid != 1981
	GROUP BY c2.yearID, c2.Most_Yearly_Wins, t.teamid 
	ORDER BY c2.yearID
)
SELECT count(*)*100.0 / (SELECT count(teamid) FROM CTE3) AS Percentage_of_Winning_the_WS
FROM CTE3 
INNER JOIN CTE1
	USING (yearID, teamID)
;



--Michael's more nuanced solution:

WITH cte AS (
	SELECT
		yearid, 
		teamid,
		w,
		wswin,
		RANK() OVER(PARTITION BY yearid ORDER BY w DESC) AS wins_rank
	FROM teams
	WHERE yearid >= 1970 AND yearid <> 1994 AND yearid <> 1981
	ORDER BY yearid, w DESC),
cte2 AS (
	SELECT *
	FROM cte
	WHERE wins_rank = 1),
cte3 AS (
	SELECT yearid, SUM(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END), COUNT(*)
	FROM cte2
	GROUP BY yearid)
SELECT SUM(sum / count) 
FROM cte3;
 
--10/46






--6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.


WITH CTE1 AS(
	SELECT *
	FROM awardsmanagers
	WHERE lgid = 'AL' AND awardid = 'TSN Manager of the Year'
	),
CTE2 AS(
	SELECT *
	FROM awardsmanagers
	WHERE lgid = 'NL' AND awardid = 'TSN Manager of the Year'
	)
SELECT DISTINCT m.playerID, pp.namefirst, pp.namelast, m.teamID, m.lgid
FROM people AS pp
INNER JOIN CTE1 AS c1
	USING (playerid)
INNER JOIN CTE2 AS c2
	USING (playerid)
INNER JOIN Managers AS m 
	ON m.playerID = c2.playerID 
ORDER BY playerID
; 


 




--7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.
--Ans: Matt Cain

WITH CTE1 AS (
	SELECT DISTINCT playerID, SUM(p.gs) AS Total_Game_Started, SUM(so) AS Total_Strike_Outs
	FROM pitching AS p
	WHERE yearid = 2016
	GROUP BY playerID
	)
SELECT DISTINCT pp.playerID, namefirst, namelast, SUM(salary) / CTE1.Total_Strike_Outs AS USD_per_Strike_Out
FROM people AS pp
INNER JOIN salaries AS sal
	USING (playerID)
INNER JOIN CTE1
	USING (playerID)
WHERE sal.yearid = 2016
	AND CTE1.Total_Game_Started >= 10
GROUP BY pp.playerID, namefirst, namelast, CTE1.Total_Strike_Outs
ORDER BY USD_per_Strike_Out DESC
; 





--8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the inducted column of the halloffame table.


WITH CTE1 AS (
	SELECT playerID, SUM(h) AS Career_Hits
	FROM batting
	GROUP BY playerID
	)
SELECT DISTINCT pp.playerID, namefirst, namelast, SUM(Career_Hits), MIN((CASE WHEN inducted = 'Y' THEN hf.yearID ELSE NULL END)) AS Year_of_Induction
FROM CTE1 AS c1
INNER JOIN people AS pp
	USING (playerID)
LEFT JOIN halloffame AS hf
	USING (playerID)
WHERE Career_Hits >= 3000 
GROUP BY pp.playerID
ORDER BY SUM(Career_Hits) DESC
;





--9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.


WITH CTE1 AS (
	SELECT playerID, teamID, SUM(h) AS Career_Hits
	FROM batting AS b
	GROUP BY playerID, teamID
	ORDER BY SUM(h) DESC
),
CTE2 AS (
	SELECT playerID, c1.teamID, c1.Career_Hits
	FROM CTE1 AS c1
	WHERE Career_Hits >= 1000   
	GROUP BY playerID, c1.teamID, c1.Career_Hits
),
CTE3 AS (
	SELECT playerid, COUNT(DISTINCT teamid) AS Num_of_Teams
	FROM CTE2 AS c2
	GROUP BY playerid
	ORDER BY Num_of_Teams DESC
),
CTE4 AS (
	SELECT playerid, c3.Num_of_Teams
	FROM CTE3 AS c3
	WHERE c3.Num_of_Teams > 1
)
SELECT pp.playerID, pp.namefirst, pp.namelast , c2.teamID, c2.Career_Hits
FROM people AS pp 
INNER JOIN CTE2 AS c2
	USING (playerID) 
INNER JOIN CTE4 as c4
	USING (playerID)
ORDER BY playerID
;




--10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.


WITH CTE1 AS (
	SELECT b.playerID, b.yearID, SUM(b.hr) AS Num_of_Homeruns_This_Yr
	FROM batting AS b
	GROUP BY b.playerID, b.yearID  -- Aggregating Num of Homeruns by year
	ORDER BY SUM(b.hr) DESC
	),
CTE2 AS (
	SELECT c1.playerID, MAX(Num_of_Homeruns_This_Yr) AS Career_Max_Yearly_Homeruns
	FROM CTE1 AS c1
	GROUP BY c1.playerID
	),
CTE3 AS (
	SELECT DISTINCT pp.playerID, pp.namefirst, pp.namelast
	FROM people AS pp 
	), 
CTE4 AS (
	SELECT yearID, playerID, COUNT(playerID) AS Num_of_Appearances_This_Yr
	FROM appearances 
	GROUP BY yearid, playerid
	),
CTE5 AS (
	SELECT playerID, SUM(CASE WHEN c4.Num_of_Appearances_This_Yr > 0 THEN 1 ELSE 0 END) AS Years_Played
	FROM CTE4 AS c4 
	GROUP BY playerID
	),	
CTE6 AS (
	SELECT DISTINCT c5.playerID, c3.namefirst, c3.namelast
	FROM CTE5 AS c5
	INNER JOIN CTE3 AS c3
		USING (playerID)
	WHERE c5.Years_Played >= 10
	GROUP BY c5.playerid, c5.Years_Played, c3.namefirst, c3.namelast
	)
SELECT c6.playerID, c6.namefirst, c6.namelast, c1.yearID, c1.Num_of_Homeruns_This_Yr, c2.Career_Max_Yearly_Homeruns 
FROM CTE6 AS c6
INNER JOIN CTE1 AS C1
	USING (playerID)
INNER JOIN CTE2 AS c2
	ON c1.playerID = c2.playerID AND c1.Num_of_Homeruns_This_Yr = c2.Career_Max_Yearly_Homeruns 
WHERE c1.yearID = 2016 AND c1.Num_of_Homeruns_This_Yr > 0
ORDER BY c1.playerID
; 






--Open-ended Qs:
--11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.




--12. In this question, you will explore the connection between number of wins and attendance.
--12a. Does there appear to be any correlation between attendance at home games and number of wins?



--12b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.



--13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?




