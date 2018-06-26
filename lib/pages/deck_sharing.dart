import 'package:flutter/material.dart';

import '../flutter/localization.dart';
import '../models/deck.dart';
import '../models/deck_access.dart';
import '../remote/error_reporting.dart';
import '../remote/user_lookup.dart';
import '../view_models/deck_access_view_model.dart';
import '../widgets/deck_access_dropdown.dart';
import '../widgets/observing_animated_list.dart';
import '../widgets/save_updates_dialog.dart';
import '../widgets/send_invite.dart';

class DeckSharingPage extends StatefulWidget {
  final Deck _deck;

  DeckSharingPage(this._deck);

  @override
  State<StatefulWidget> createState() => new _DeckSharingState();
}

class _DeckSharingState extends State<DeckSharingPage> {
  final TextEditingController _textController = new TextEditingController();
  AccessType _accessValue = AccessType.write;

  @override
  Widget build(BuildContext context) => new Scaffold(
        appBar: new AppBar(
          title: new Text(widget._deck.name),
          actions: <Widget>[
            new IconButton(
                icon: new Icon(Icons.send),
                onPressed:
                    _isEmailCorrect() ? () => _shareDeck(_accessValue) : null)
          ],
        ),
        body: new Column(
          children: <Widget>[
            new Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0),
              child: new Row(
                children: <Widget>[
                  new Text(AppLocalizations.of(context).peopleLabel),
                ],
              ),
            ),
            _sharingEmail(),
            new Expanded(child: new DeckUsersWidget(widget._deck)),
          ],
        ),
      );

  Widget _sharingEmail() {
    return new ListTile(
      title: new TextField(
        controller: _textController,
        onChanged: (String text) {
          setState(() {});
        },
        decoration: new InputDecoration(
          hintText: AppLocalizations.of(context).emailAddressHint,
        ),
      ),
      trailing: new DeckAccessDropdown(
        value: _accessValue,
        filter: (AccessType access) =>
            (access != AccessType.owner && access != null),
        valueChanged: (AccessType access) => setState(() {
              _accessValue = access;
            }),
      ),
    );
  }

  bool _isEmailCorrect() {
    return _textController.text.contains('@');
  }

  //TODO(ksheremet): Disable sharing button
  _shareDeck(AccessType deckAccess) async {
    print("Share deck: " + deckAccess.toString() + _textController.text);
    try {
      String uid = await userLookup(_textController.text.toString());
      if (uid == null) {
        await _inviteUser();
      } else {
        //TODO(ksheremet): Share deck
      }
      //TODO(ksheremet): do not clear if user declines to send invite
      setState(() {
        _textController.clear();
      });
    } catch (e, stackTrace) {
      //TODO(ksheremet): show error message to the user
      reportError("Deck sharing exception:", e, stackTrace);
    }
  }

  _inviteUser() async {
    var locale = AppLocalizations.of(context);
    var inviteUser = await showSaveUpdatesDialog(
        context: context,
        changesQuestion: locale.appNotInstalledSharingDeck,
        yesAnswer: locale.send,
        noAnswer: locale.cancel);
    if (inviteUser) {
      sendInvite(context);
      setState(() {
        _textController.clear();
      });
    }
  }
}

class DeckUsersWidget extends StatefulWidget {
  final Deck _deck;

  DeckUsersWidget(this._deck);

  @override
  State<StatefulWidget> createState() => _DeckUsersState();
}

class _DeckUsersState extends State<DeckUsersWidget> {
  DeckAccessesViewModel _deckAccessesViewModel;
  bool _active = false;

  @override
  void initState() {
    _deckAccessesViewModel = new DeckAccessesViewModel(widget._deck.key);
    _deckAccessesViewModel.deckAccesses.comparator = (a, b) {
      if (a.access == b.access) {
        return (a.user?.name ?? '').compareTo(b.user?.name ?? '');
      }

      switch (a.access) {
        case AccessType.owner:
          return -1;
        case AccessType.write:
          return b.access == AccessType.owner ? 1 : -1;
        default:
          return 1;
      }
    };
    super.initState();
  }

  @override
  void deactivate() {
    _deckAccessesViewModel.deactivate();
    _active = false;
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    _deckAccessesViewModel.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      _deckAccessesViewModel.activate();
      _active = true;
    }
    return new Column(
      children: <Widget>[
        new Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          child: new Row(
            children: <Widget>[
              new Text(AppLocalizations.of(context).whoHasAccessLabel),
            ],
          ),
        ),
        new Expanded(
          child: new ObservingAnimatedList(
              list: _deckAccessesViewModel.deckAccesses,
              itemBuilder: (context, item, animation, index) =>
                  new SizeTransition(
                    child: _buildUserAccessInfo(item),
                    sizeFactor: animation,
                  )),
        ),
      ],
    );
  }

  Widget _buildUserAccessInfo(DeckAccessViewModel accessViewModel) {
    Function filter;
    if (accessViewModel.access == AccessType.owner) {
      filter = (AccessType access) => access == AccessType.owner;
    } else {
      filter = (AccessType access) => access != AccessType.owner;
    }

    return new ListTile(
      leading: (accessViewModel.user == null)
          ? null
          : new CircleAvatar(
              backgroundImage: new NetworkImage(accessViewModel.user.photoUrl),
            ),
      title: (accessViewModel.user == null)
          ? new Center(
              child: new CircularProgressIndicator(),
            )
          : new Text(accessViewModel.user.name),
      trailing: new DeckAccessDropdown(
        value: accessViewModel.access,
        filter: filter,
        valueChanged: (AccessType access) => setState(() {
              // TODO(ksheremet): Save new access to deck.
            }),
      ),
    );
  }
}
