const GitHub = require('github-api')
const { exec } = require('child_process')

// token auth
let gh = new GitHub(
	{
		token: 'secretToken'
	},
	'https://github.comcast.com/api/v3'
)

let mesh = gh.getOrganization('mesh')

mesh.getRepos(async (err, repos) => {
	console.log(repos.length)
	for (let i = 0; i < repos.length; i++) {
		exec(
			'cd ~/Plume/mesh ; git clone ' + repos[i].ssh_url,
			(err, stdout, stderr) => {
				if (err) {
					console.log(err)
					// node couldn't execute the command
					return
				}
				console.log(`Cloned Repo: ` + repos[i].ssh_url)
				// console.log(`stderr: ${stderr}`)
			}
		)
	}
})
