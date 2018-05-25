
use std::fmt;
use std::ops::FnOnce;

error_chain! { }

pub struct FormattedError<'a> {
    value: &'a Error
}

impl<'a> fmt::Display for FormattedError<'a> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let e = self.value;
        write!(f, "{}", e)?;
        let mut last_error = e.to_string();
        for e in e.iter().skip(1) {
            let this_err: String = e.to_string();
            if last_error != this_err {
                writeln!(f, " [due to]:")?;
                write!(f, "     ➥ {}", e)?;
            }
            last_error = this_err
        }

        // The backtrace is generated with environment `RUST_BACKTRACE=1`.
        if let Some(backtrace) = e.backtrace() {
            writeln!(f, "")?;
            writeln!(f, "   =>: {:?}", backtrace)?;
        }
        Ok(())
    }
}

impl Error {
    pub fn format<'a>(&'a self) -> FormattedError<'a> {
        FormattedError{value: self}
    }
}
