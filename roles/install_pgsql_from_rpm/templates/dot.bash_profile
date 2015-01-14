# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH={{ pghome }}/bin:$PATH:$HOME/bin
LD_LIBRAY_PATH={{ pghome }}/lib:$LD_LIBRAY_PATH
PGDATA={{ pgdata }}
PGPORT={{ pgport }}

export PATH LD_LIBRAY_PATH PGDATA PGPORT
