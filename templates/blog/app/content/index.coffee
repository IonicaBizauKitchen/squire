pageData: (app, _) ->
	articles = []
	
	for articleId, articleDirectory of app.getPath("content/articles").directories
		article         = articleDirectory.files["index.md"]
		article.data.id = articleId
		articles.push article
	
	articles: _.sortBy(articles, (article) -> article.data.date).reverse()
	template: "templates/index.jade"
