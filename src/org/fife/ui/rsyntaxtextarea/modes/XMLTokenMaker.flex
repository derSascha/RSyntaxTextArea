/*
 * 01/24/2005
 *
 * XMLTokenMaker.java - Generates tokens for XML syntax highlighting.
 * Copyright (C) 2005 Robert Futrell
 * robert_futrell at users.sourceforge.net
 * http://fifesoft.com/rsyntaxtextarea
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA.
 */
package org.fife.ui.rsyntaxtextarea.modes;

import java.io.*;
import javax.swing.text.Segment;

import org.fife.ui.rsyntaxtextarea.*;


/**
 * Scanner for XML.
 *
 * This implementation was created using
 * <a href="http://www.jflex.de/">JFlex</a> 1.4.1; however, the generated file
 * was modified for performance.  Memory allocation needs to be almost
 * completely removed to be competitive with the handwritten lexers (subclasses
 * of <code>AbstractTokenMaker</code>, so this class has been modified so that
 * Strings are never allocated (via yytext()), and the scanner never has to
 * worry about refilling its buffer (needlessly copying chars around).
 * We can achieve this because RText always scans exactly 1 line of tokens at a
 * time, and hands the scanner this line as an array of characters (a Segment
 * really).  Since tokens contain pointers to char arrays instead of Strings
 * holding their contents, there is no need for allocating new memory for
 * Strings.<p>
 *
 * The actual algorithm generated for scanning has, of course, not been
 * modified.<p>
 *
 * If you wish to regenerate this file yourself, keep in mind the following:
 * <ul>
 *   <li>The generated <code>XMLTokenMaker.java</code> file will contain two
 *       definitions of both <code>zzRefill</code> and <code>yyreset</code>.
 *       You should hand-delete the second of each definition (the ones
 *       generated by the lexer), as these generated methods modify the input
 *       buffer, which we'll never have to do.</li>
 *   <li>You should also change the declaration/definition of zzBuffer to NOT
 *       be initialized.  This is a needless memory allocation for us since we
 *       will be pointing the array somewhere else anyway.</li>
 *   <li>You should NOT call <code>yylex()</code> on the generated scanner
 *       directly; rather, you should use <code>getTokenList</code> as you would
 *       with any other <code>TokenMaker</code> instance.</li>
 * </ul>
 *
 * @author Robert Futrell
 * @version 0.5
 *
 */
%%

%public
%class XMLTokenMaker
%extends AbstractMarkupTokenMaker
%unicode
%type org.fife.ui.rsyntaxtextarea.Token


%{

	/**
	 * Token type specific to XMLTokenMaker; this signals that the user has
	 * ended a line with an unclosed XML tag; thus a new line is beginning
	 * still inside of the tag.
	 */
	public static final int INTERNAL_INTAG					= -1;


	/**
	 * Constructor.  This must be here because JFlex does not generate a
	 * no-parameter constructor.
	 */
	public XMLTokenMaker() {
		super();
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int tokenType) {
		addToken(zzStartRead, zzMarkedPos-1, tokenType);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param tokenType The token's type.
	 */
	private void addToken(int start, int end, int tokenType) {
		int so = start + offsetShift;
		addToken(zzBuffer, start,end, tokenType, so);
	}


	/**
	 * Adds the token specified to the current linked list of tokens.
	 *
	 * @param array The character array.
	 * @param start The starting offset in the array.
	 * @param end The ending offset in the array.
	 * @param tokenType The token's type.
	 * @param startOffset The offset in the document at which this token
	 *                    occurs.
	 */
	public void addToken(char[] array, int start, int end, int tokenType, int startOffset) {
		super.addToken(array, start,end, tokenType, startOffset);
		zzStartRead = zzMarkedPos;
	}


	/**
	 * Always returns <tt>false</tt>, as you never want "mark occurrences"
	 * working in XML files.
	 *
	 * @param type The token type.
	 * @return Whether tokens of this type should have "mark occurrences"
	 *         enabled.
	 */
	public boolean getMarkOccurrencesOfTokenType(int type) {
		return false;
	}


	/**
	 * Returns the first token in the linked list of tokens generated
	 * from <code>text</code>.  This method must be implemented by
	 * subclasses so they can correctly implement syntax highlighting.
	 *
	 * @param text The text from which to get tokens.
	 * @param initialTokenType The token type we should start with.
	 * @param startOffset The offset into the document at which
	 *        <code>text</code> starts.
	 * @return The first <code>Token</code> in a linked list representing
	 *         the syntax highlighted text.
	 */
	public Token getTokenList(Segment text, int initialTokenType, int startOffset) {

		resetTokenList();
		this.offsetShift = -text.offset + startOffset;

		// Start off in the proper state.
		int state = Token.NULL;
		switch (initialTokenType) {
			case Token.COMMENT_MULTILINE:
				state = COMMENT;
				start = text.offset;
				break;
			case Token.FUNCTION:
				state = DTD;
				start = text.offset;
				break;
			case Token.LITERAL_STRING_DOUBLE_QUOTE:
				state = INATTR_DOUBLE;
				start = text.offset;
				break;
			case Token.LITERAL_CHAR:
				state = INATTR_SINGLE;
				start = text.offset;
				break;
			case Token.PREPROCESSOR:
				state = PI;
				start = text.offset;
				break;
			case INTERNAL_INTAG:
				state = INTAG;
				start = text.offset;
				break;
			case Token.VARIABLE:
				state = CDATA;
				start = text.offset;
				break;
			default:
				state = Token.NULL;
		}

		s = text;
		try {
			yyreset(zzReader);
			yybegin(state);
			return yylex();
		} catch (IOException ioe) {
			ioe.printStackTrace();
			return new DefaultToken();
		}

	}


	/**
	 * Refills the input buffer.
	 *
	 * @return      <code>true</code> if EOF was reached, otherwise
	 *              <code>false</code>.
	 */
	private boolean zzRefill() {
		return zzCurrentPos>=s.offset+s.count;
	}


	/**
	 * Resets the scanner to read from a new input stream.
	 * Does not close the old reader.
	 *
	 * All internal variables are reset, the old input stream 
	 * <b>cannot</b> be reused (internal buffer is discarded and lost).
	 * Lexical state is set to <tt>YY_INITIAL</tt>.
	 *
	 * @param reader   the new input stream 
	 */
	public final void yyreset(java.io.Reader reader) {
		// 's' has been updated.
		zzBuffer = s.array;
		/*
		 * We replaced the line below with the two below it because zzRefill
		 * no longer "refills" the buffer (since the way we do it, it's always
		 * "full" the first time through, since it points to the segment's
		 * array).  So, we assign zzEndRead here.
		 */
		//zzStartRead = zzEndRead = s.offset;
		zzStartRead = s.offset;
		zzEndRead = zzStartRead + s.count - 1;
		zzCurrentPos = zzMarkedPos = zzPushbackPos = s.offset;
		zzLexicalState = YYINITIAL;
		zzReader = reader;
		zzAtBOL  = true;
		zzAtEOF  = false;
	}


%}

LetterOrDigit		= ([A-Za-z0-9])
Whitespace			= ([ \t\f])
LineTerminator			= ([\n])
Identifier			= ([^ \t\n<&]+)
AmperItem				= ([&][^; \t]*[;]?)
InTagIdentifier		= ([^ \t\n\"\'=\/>]+)
CDataBegin			= ("<![CDATA[")
CDataEnd				= ("]]>")

%state COMMENT
%state PI
%state DTD
%state INTAG
%state INATTR_DOUBLE
%state INATTR_SINGLE
%state CDATA

%%

<YYINITIAL> {
	"<!--"						{ start = zzMarkedPos-4; yybegin(COMMENT); }
	{CDataBegin}					{ addToken(Token.DATA_TYPE); start = zzMarkedPos; yybegin(CDATA); }
	"<!"							{ start = zzMarkedPos-2; yybegin(DTD); }
	"<?"							{ start = zzMarkedPos-2; yybegin(PI); }
	"<"{LetterOrDigit}+			{
									int count = yylength();
									addToken(zzStartRead,zzStartRead, Token.MARKUP_TAG_DELIMITER);
									addToken(zzMarkedPos-(count-1), zzMarkedPos-1, Token.MARKUP_TAG_NAME);
									yybegin(INTAG);
								}
	"</"{LetterOrDigit}+		{
									int count = yylength();
									addToken(zzStartRead,zzStartRead+1, Token.MARKUP_TAG_DELIMITER);
									addToken(zzMarkedPos-(count-2), zzMarkedPos-1, Token.MARKUP_TAG_NAME);
									yybegin(INTAG);
								}
	"<"							{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(INTAG); }
	"</"						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(INTAG); }
	{LineTerminator}				{ addNullToken(); return firstToken; }
	{Identifier}					{ addToken(Token.IDENTIFIER); }
	{AmperItem}					{ addToken(Token.DATA_TYPE); }
	{Whitespace}+					{ addToken(Token.WHITESPACE); }
	<<EOF>>						{ addNullToken(); return firstToken; }
}

<COMMENT> {
	[^\n\-]+						{}
	{LineTerminator}				{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); return firstToken; }
	"-->"						{ yybegin(YYINITIAL); addToken(start,zzStartRead+2, Token.COMMENT_MULTILINE); }
	"-"							{}
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); return firstToken; }
}

<PI> {
	[^\n\?]+						{}
	{LineTerminator}				{ addToken(start,zzStartRead-1, Token.PREPROCESSOR); return firstToken; }
	"?>"							{ yybegin(YYINITIAL); addToken(start,zzStartRead+1, Token.PREPROCESSOR); }
	"?"							{}
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.PREPROCESSOR); return firstToken; }
}

<DTD> {
	[^\n>]+					{}
	{LineTerminator}			{ addToken(start,zzStartRead-1, Token.FUNCTION); return firstToken; }
	">"						{ yybegin(YYINITIAL); addToken(start,zzStartRead, Token.FUNCTION); }
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.FUNCTION); return firstToken; }
}

<INTAG> {
	{InTagIdentifier}				{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	{Whitespace}+					{ addToken(Token.WHITESPACE); }
	"="							{ addToken(Token.OPERATOR); }
	"/"							{ addToken(Token.MARKUP_TAG_DELIMITER); /* Not valid but we'll still accept it */ }
	"/>"						{ yybegin(YYINITIAL); addToken(Token.MARKUP_TAG_DELIMITER); }
	">"							{ yybegin(YYINITIAL); addToken(Token.MARKUP_TAG_DELIMITER); }
	[\"]						{ start = zzMarkedPos-1; yybegin(INATTR_DOUBLE); }
	[\']						{ start = zzMarkedPos-1; yybegin(INATTR_SINGLE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, INTERNAL_INTAG); return firstToken; }
}

<INATTR_DOUBLE> {
	[^\"]*						{}
	[\"]						{ yybegin(INTAG); addToken(start,zzStartRead, Token.LITERAL_STRING_DOUBLE_QUOTE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.LITERAL_STRING_DOUBLE_QUOTE); return firstToken; }
}

<INATTR_SINGLE> {
	[^\']*						{}
	[\']						{ yybegin(INTAG); addToken(start,zzStartRead, Token.LITERAL_CHAR); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.LITERAL_CHAR); return firstToken; }
}

<CDATA> {
	[^\]]+						{}
	{CDataEnd}					{ int temp=zzStartRead; yybegin(YYINITIAL); addToken(start,zzStartRead-1, Token.VARIABLE); addToken(temp,zzMarkedPos-1, Token.DATA_TYPE); }
	"]"							{}
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.VARIABLE); return firstToken; }
}
